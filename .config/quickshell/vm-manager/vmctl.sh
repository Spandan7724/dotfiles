#!/usr/bin/env bash
#
# Backend for the VM manager window. Every VM is a normal libvirt domain on
# qemu:///system, so virt-manager, virsh and this window all see the same VMs.
#
# ISOs are downloaded with quickget (from quickemu), then uploaded into a
# libvirt storage pool. Uploading through libvirt, rather than pointing the VM
# at ~/..., matters because the home directory is private and QEMU runs as its
# own user; it also needs no sudo, only membership of the libvirt group.
#
#   vmctl.sh list                         JSON: { vms: [...], jobs: [...] }
#   vmctl.sh catalog [--refresh]          JSON: quickget's downloadable OSes
#   vmctl.sh isos                         JSON: ISOs already in the ISO pool
#   vmctl.sh start|shutdown|reboot|destroy|console|details|delete NAME
#   vmctl.sh create NAME CPUS RAM_MIB DISK_GIB uefi|bios 3d|basic LABEL quickget OS RELEASE [EDITION]
#   vmctl.sh create NAME CPUS RAM_MIB DISK_GIB uefi|bios 3d|basic LABEL iso PATH
#   vmctl.sh create NAME CPUS RAM_MIB DISK_GIB uefi|bios 3d|basic LABEL pool VOLUME
#   vmctl.sh cancel|dismiss NAME          stop or forget a creation job

set -uo pipefail

uri=qemu:///system
iso_pool=vm-isos
iso_dir=/var/lib/libvirt/isos
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/vm-manager"
job_dir="${XDG_STATE_HOME:-$HOME/.local/state}/vm-manager/jobs"
mkdir -p "$cache_dir" "$job_dir"

v() { virsh -c "$uri" -q "$@"; }

die() {
    printf '%s\n' "$1" >&2
    command -v notify-send >/dev/null && notify-send -u critical 'Virtual machines' "$1"
    exit 1
}

valid_name() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$ ]]; }

# --- queries ---------------------------------------------------------------

list_vms() {
    local name info
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        info="$(v dominfo "$name" 2>/dev/null)" || continue
        jq -n --arg name "$name" --arg info "$info" --arg label "$(v desc "$name" 2>/dev/null)" '
            def field($k): ($info | capture("(?m)^" + $k + ":\\s*(?<v>.*)$").v // "");
            {
                name: $name,
                label: $label,
                state: field("State"),
                cpus: (field("CPU\\(s\\)") | tonumber? // 0),
                memoryMiB: ((field("Max memory") | capture("(?<n>[0-9]+)").n | tonumber? // 0) / 1024 | floor),
                autostart: (field("Autostart") == "enable")
            }'
    done < <(v list --all --name 2>/dev/null) | jq -s 'sort_by(.name)'
}

list_jobs() {
    local file
    for file in "$job_dir"/*.json; do
        [[ -f "$file" ]] && cat "$file"
    done | jq -s 'sort_by(.name)'
}

cmd_list() {
    local vms jobs libvirt_ok=true
    v uri >/dev/null 2>&1 || libvirt_ok=false
    vms="$(list_vms)" || vms='[]'
    jobs="$(list_jobs)" || jobs='[]'
    jq -n --argjson vms "${vms:-[]}" --argjson jobs "${jobs:-[]}" --argjson ok "$libvirt_ok" \
        '{ libvirt: $ok, vms: $vms, jobs: $jobs }'
}

# quickget --list-csv: Display Name,OS,Release,Option,Downloader,PNG,SVG. The
# list is slow to build (it queries upstream mirrors), so it is cached for a
# week. macOS is dropped: it needs quickemu's own OpenCore setup, not libvirt.
cmd_catalog() {
    local cache="$cache_dir/catalog.json"
    if ! command -v quickget >/dev/null 2>&1; then
        jq -n '{ error: "quickget is not installed (package: quickemu)", items: [] }'
        return
    fi
    if [[ "${1:-}" == --refresh || ! -s "$cache" ]] || [[ -n "$(find "$cache" -mtime +7 2>/dev/null)" ]]; then
        quickget --list-csv 2>/dev/null | tail -n +2 | jq -R -s '
            split("\n") | map(select(length > 0) | split(",")) |
            map(select(.[1] != "macos")) |
            map({ name: .[0], os: .[1], release: .[2], edition: .[3], icon: .[5] }) |
            { error: "", items: . }' >"$cache.tmp" && mv -f "$cache.tmp" "$cache"
    fi
    cat "$cache"
}

cmd_isos() {
    v pool-info "$iso_pool" >/dev/null 2>&1 || { echo '[]'; return; }
    v pool-refresh "$iso_pool" >/dev/null 2>&1
    v vol-list "$iso_pool" --details 2>/dev/null | awk '{ print $1 }' | jq -R -s 'split("\n") | map(select(endswith(".iso")))'
}

# --- VM actions ------------------------------------------------------------

open_console() {
    # --attach hands the display over through libvirt, which works for every
    # VM and is the only way in for 3D ones: their SPICE has no network listener.
    local -a opts=(--attach --wait --reconnect)
    # 3D VMs run at the host's physical resolution (see host_resolution). On a
    # HiDPI host, auto-resize would shrink them to the window's logical size
    # and upscale the result, which is what makes the picture blurry.
    if v dumpxml "$1" 2>/dev/null | grep -q "accel3d='yes'"; then
        opts+=(--auto-resize=never)
    fi
    setsid -f virt-viewer --connect "$uri" "${opts[@]}" "$1" >/dev/null 2>&1
}

cmd_delete() {
    local name="$1" targets
    [[ "$(v domstate "$name" 2>/dev/null)" == "shut off" ]] || v destroy "$name" >/dev/null 2>&1
    # Only the VM's own disks are removed. Its CD-ROM is an ISO that other VMs
    # may share, so it is left in the ISO pool.
    targets="$(v domblklist "$name" --details | awk '$2 == "disk" { print $3 }' | paste -sd, -)"
    v undefine "$name" --nvram --tpm --managed-save --snapshots-metadata ${targets:+--storage "$targets"} >/dev/null
}

# --- creation --------------------------------------------------------------

write_status() { # write_status PHASE PERCENT MESSAGE
    jq -n --arg name "$job_name" --arg label "$job_label" --arg phase "$1" \
        --argjson percent "${2:-0}" --arg message "$3" --argjson pid "$$" \
        '{ name: $name, label: $label, phase: $phase, percent: $percent, message: $message, pid: $pid }' \
        >"$job_dir/$job_name.json.tmp" && mv -f "$job_dir/$job_name.json.tmp" "$job_dir/$job_name.json"
}

fail() {
    write_status error 0 "$1"
    notify-send -u critical "Could not create $job_name" "$1" 2>/dev/null
    exit 1
}

# Physical pixel size of the host's focused monitor, e.g. "3200 2000". The
# guest renders at this size and applies its own scaling, so the console shows
# it pixel for pixel instead of stretching a half-size picture.
host_resolution() {
    local size mode
    if command -v hyprctl >/dev/null 2>&1; then
        size="$(hyprctl monitors -j 2>/dev/null | jq -r '(map(select(.focused)) + .)[0] | "\(.width) \(.height)"' 2>/dev/null)"
        [[ "$size" =~ ^[0-9]+\ [0-9]+$ ]] && { printf '%s\n' "$size"; return 0; }
    fi
    # Without Hyprland: the preferred mode of the first connected display.
    for mode in /sys/class/drm/card*-*/modes; do
        [[ "$(<"${mode%/modes}/status")" == connected ]] || continue
        size="$(head -n1 "$mode" | tr 'x' ' ')"
        [[ "$size" =~ ^[0-9]+\ [0-9]+$ ]] && { printf '%s\n' "$size"; return 0; }
    done
    return 1
}

# The GPU that renders a 3D guest. NVIDIA's proprietary driver handles virgl
# poorly, so any other GPU (the integrated one on a hybrid laptop) wins.
render_node() {
    local node fallback=""
    for node in /sys/class/drm/renderD*; do
        [[ -e "$node" ]] || continue
        if [[ "$(<"$node/device/vendor")" != 0x10de ]]; then
            printf '/dev/dri/%s\n' "${node##*/}"
            return 0
        fi
        fallback="${fallback:-/dev/dri/${node##*/}}"
    done
    [[ -n "$fallback" ]] && printf '%s\n' "$fallback"
}

ensure_iso_pool() {
    v pool-info "$iso_pool" >/dev/null 2>&1 && { v pool-start "$iso_pool" >/dev/null 2>&1; return 0; }
    v pool-define-as "$iso_pool" dir --target "$iso_dir" >/dev/null &&
        v pool-build "$iso_pool" >/dev/null &&
        v pool-start "$iso_pool" >/dev/null &&
        v pool-autostart "$iso_pool" >/dev/null
}

import_iso() { # import_iso FILE VOLUME
    local size
    size="$(stat -c %s "$1")"
    write_status importing 0 "Copying the ISO into libvirt storage"
    v vol-create-as "$iso_pool" "$2" "$size" --format raw >/dev/null || return 1
    v vol-upload --pool "$iso_pool" "$2" "$1" || { v vol-delete --pool "$iso_pool" "$2" >/dev/null 2>&1; return 1; }
}

download_iso() { # download_iso OS RELEASE EDITION VOLUME
    local os="$1" release="$2" edition="$3" volume="$4" dir iso line percent
    command -v quickget >/dev/null 2>&1 || fail "quickget is not installed (package: quickemu)."
    dir="$cache_dir/downloads/$job_name"
    rm -rf -- "$dir"
    mkdir -p "$dir"
    write_status downloading 0 "Starting download"
    # quickget draws a curl progress bar with carriage returns; each redraw
    # carries the percentage.
    (cd "$dir" && quickget --download "$os" "$release" ${edition:+"$edition"}) 2>&1 |
        tr '\r' '\n' | tee -a "$job_dir/$job_name.log" | while IFS= read -r line; do
            if [[ "$line" =~ ([0-9]{1,3})(\.[0-9])?% ]]; then
                percent="${BASH_REMATCH[1]}"
                ((percent % 2 == 0)) && write_status downloading "$percent" "Downloading"
            fi
        done
    ((PIPESTATUS[0] == 0)) || fail "The download failed. See $job_dir/$job_name.log"
    iso="$(find "$dir" -maxdepth 1 -type f -iname '*.iso' -print -quit)"
    [[ -n "$iso" ]] || fail "This OS is not distributed as an ISO, so it cannot be installed this way."
    import_iso "$iso" "$volume" || fail "Could not copy the ISO into the $iso_pool pool."
    rm -rf -- "$dir"
}

# The commas in the --boot values are virt-install option syntax.
# shellcheck disable=SC2054
run_job() {
    local cpus="$1" ram="$2" disk="$3" firmware="$4" graphics="$5" source="$6"
    shift 6
    local volume os="" release=""

    ensure_iso_pool || fail "Could not create the $iso_pool storage pool."

    case "$source" in
        quickget)
            os="$1" release="$2"
            local edition="${3:-}"
            volume="$(printf '%s-%s%s.iso' "$os" "$release" "${edition:+-$edition}" | tr -c 'A-Za-z0-9._\n-' '_')"
            if v vol-info --pool "$iso_pool" "$volume" >/dev/null 2>&1; then
                write_status importing 100 "Reusing the ISO downloaded earlier"
            else
                download_iso "$os" "$release" "$edition" "$volume"
            fi
            ;;
        iso)
            [[ -f "$1" ]] || fail "ISO not found: $1"
            volume="$(basename "$1" | tr -c 'A-Za-z0-9._\n-' '_')"
            v vol-info --pool "$iso_pool" "$volume" >/dev/null 2>&1 ||
                import_iso "$1" "$volume" || fail "Could not copy the ISO into the $iso_pool pool."
            ;;
        pool)
            volume="$1"
            ;;
        *) fail "Unknown source: $source" ;;
    esac

    local iso_path
    iso_path="$(v vol-path --pool "$iso_pool" "$volume")" || fail "The ISO $volume is missing from the $iso_pool pool."

    # libosinfo recognises most installers from the ISO itself; the fallback
    # only matters when it cannot.
    local fallback=linux2024
    case "$os" in
        windows) [[ "$release" == 10 ]] && fallback=win10 || fallback=win11 ;;
        windows-server) fallback=win2k22 ;;
        freebsd | ghostbsd) fallback=freebsd14.0 ;;
    esac
    [[ "$volume" =~ ^[Ww]in(dows)?[-_]?1[01]|^Win1[01]_ ]] && fallback=win11

    local -a boot=()
    if [[ "$firmware" == bios ]]; then
        # Left unset on purpose: firmware=bios asks libvirt to auto-select a
        # descriptor, and Arch's seabios ships none. QEMU's default is SeaBIOS.
        :
    elif [[ "$fallback" == win* ]]; then
        # Windows 11 requires Secure Boot and a TPM 2.0.
        boot=(--boot uefi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=yes,firmware.feature1.name=enrolled-keys,firmware.feature1.enabled=yes
            --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb)
    else
        # Many live ISOs (Arch included) are not signed for Secure Boot.
        boot=(--boot uefi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no)
    fi

    # 3D: a virtio GPU with virgl, rendered by the host through SPICE's local
    # OpenGL path, which is what Wayland compositors such as Hyprland need.
    # Windows has no virgl driver, so it always gets the basic display.
    local -a display=(--graphics spice)
    if [[ "$graphics" == 3d && "$fallback" != win* ]]; then
        local node
        node="$(render_node)" || fail "No GPU render node found for 3D acceleration."
        display=(--video model.type=virtio,model.acceleration.accel3d=yes
            --graphics "spice,gl.enable=yes,gl.rendernode=$node,listen=none")
        local width height
        if read -r width height < <(host_resolution); then
            display+=(--xml "./devices/video/model/resolution/@x=$width"
                --xml "./devices/video/model/resolution/@y=$height")
        fi
    fi

    write_status creating 0 "Creating the virtual machine"
    virt-install --connect "$uri" --name "$job_name" --metadata description="$job_label" \
        --vcpus "$cpus" --memory "$ram" --disk size="$disk",format=qcow2 \
        --cdrom "$iso_path" --osinfo detect=on,name="$fallback" \
        --network network=default "${display[@]}" "${boot[@]}" \
        --noautoconsole >>"$job_dir/$job_name.log" 2>&1 ||
        fail "virt-install failed: $(grep -m1 '^ERROR' "$job_dir/$job_name.log" | sed 's/^ERROR *//')"

    rm -f -- "$job_dir/$job_name.json" "$job_dir/$job_name.log"
    notify-send 'Virtual machine created' "$job_name ($job_label) is booting its installer." 2>/dev/null
    open_console "$job_name"
}

cmd_create() {
    (($# >= 9)) || die "Usage: vmctl.sh create NAME CPUS RAM DISK uefi|bios 3d|basic LABEL SOURCE ARGS..."
    local name="$1"
    valid_name "$name" || die "VM names may use letters, digits, dot, dash and underscore."
    v dominfo "$name" >/dev/null 2>&1 && die "A VM called $name already exists."
    [[ -f "$job_dir/$name.json" ]] && die "$name is already being created."
    [[ "$2$3$4" =~ ^[0-9]+$ ]] || die "CPU, memory and disk must be numbers."
    : >"$job_dir/$name.log"
    # Written here as well as by the job, so the VM appears in the list at once.
    job_name="$name" job_label="$7"
    write_status queued 0 "Starting"
    # Detached so the window can close while a multi-gigabyte download runs.
    setsid -f "$0" _job "$@" >/dev/null 2>&1
}

cmd_cancel() {
    local file="$job_dir/$1.json" pid
    if [[ -f "$file" ]]; then
        pid="$(jq -r '.pid' "$file")"
        # The job is its own session leader (setsid), so this stops quickget
        # and curl along with it.
        [[ "$pid" =~ ^[0-9]+$ ]] && kill -- "-$pid" 2>/dev/null
    fi
    rm -rf -- "$file" "$job_dir/$1.log" "$cache_dir/downloads/$1"
}

# --- dispatch ----------------------------------------------------------------

action="${1:-}"
shift || true

case "$action" in
    list) cmd_list ;;
    catalog) cmd_catalog "$@" ;;
    isos) cmd_isos ;;
    start) v start "$1" >/dev/null && open_console "$1" ;;
    shutdown) v shutdown "$1" >/dev/null ;;
    reboot) v reboot "$1" >/dev/null ;;
    destroy) v destroy "$1" >/dev/null ;;
    console) open_console "$1" ;;
    details) setsid -f virt-manager --connect "$uri" --show-domain-editor "$1" >/dev/null 2>&1 ;;
    manager) setsid -f virt-manager --connect "$uri" >/dev/null 2>&1 ;;
    delete) cmd_delete "$1" ;;
    create) cmd_create "$@" ;;
    _job)
        job_name="$1" job_label="$7"
        write_status queued 0 "Starting"
        run_job "$2" "$3" "$4" "$5" "$6" "${@:8}"
        ;;
    cancel) cmd_cancel "$1" ;;
    dismiss) rm -f -- "$job_dir/$1.json" "$job_dir/$1.log" ;;
    *) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
