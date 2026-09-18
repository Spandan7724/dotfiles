#!/usr/bin/env bash

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
PACKAGE_DIR="$REPO_DIR/packages"
BACKUP_ROOT="$HOME/.config-backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

AUR_HELPER=""
YAY_BUILD_DIR=""
INSTALL_FAILURES=0
VERIFY_FAILURES=0
PHASE_INDEX=0
PHASE_TOTAL=0
START_TIME=0
PHASE_RULE="────────────────────────────────────────"
BACKUP_CREATED=false

IGPU_PCI_ADDRESS=""
IGPU_VENDOR_ID=""
NVIDIA_PCI_ADDRESS=""
NVIDIA_DEVICE_ID=""
NVIDIA_DRIVER_PACKAGE=""
CPU_VENDOR=""
INTERNAL_OUTPUT=""
INTERNAL_RESOLUTION=""
HARDWARE_CONFIGURATION="not detected"

PACKAGES=()
OFFICIAL_PACKAGES=()
AUR_PACKAGES=()
UNKNOWN_PACKAGES=()

# Colors are enabled only on a terminal, so piping the installer to a log file
# produces clean text instead of escape sequences. NO_COLOR is honoured.
# https://no-color.org/
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'
    C_BLUE=$'\033[1;34m'
    C_GREEN=$'\033[1;32m'
    C_YELLOW=$'\033[1;33m'
    C_RED=$'\033[1;31m'
    C_CYAN=$'\033[1;36m'
    C_DIM=$'\033[2m'
    C_HIDE_CURSOR=$'\033[?25l'
    C_SHOW_CURSOR=$'\033[?25h'
else
    C_RESET=""
    C_BLUE=""
    C_GREEN=""
    C_YELLOW=""
    C_RED=""
    C_CYAN=""
    C_DIM=""
    C_HIDE_CURSOR=""
    C_SHOW_CURSOR=""
fi

info() {
    printf '\n%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$1"
}

success() {
    printf '\n%s[DONE]%s %s\n' "$C_GREEN" "$C_RESET" "$1"
}

warning() {
    printf '\n%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$1"
}

error() {
    printf '\n%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$1" >&2
}

format_duration() {
    local total="$1"
    if ((total < 60)); then
        printf '%ds' "$total"
    else
        printf '%dm%02ds' "$((total / 60))" "$((total % 60))"
    fi
}

# Numbered banner before each phase, with the time the previous phase took.
# On a long install this is the difference between "is it stuck?" and knowing
# exactly which of the twenty-two steps is running.
run_phase() {
    local label="$1"
    local phase_function="$2"
    local started elapsed status

    ((PHASE_INDEX += 1))
    started="$SECONDS"

    printf '\n%s%s  [%02d/%02d]  %s%s\n' \
        "$C_CYAN" "$PHASE_RULE" "$PHASE_INDEX" "$PHASE_TOTAL" "$label" "$C_RESET"

    "$phase_function"
    status="$?"

    elapsed="$((SECONDS - started))"
    printf '%s        %s finished in %s%s\n' \
        "$C_DIM" "$label" "$(format_duration "$elapsed")" "$C_RESET"

    return "$status"
}

# Animated progress bar for operations that are slow but silent. Redraws in
# place on a terminal and stays quiet when the output is redirected.
progress_bar() {
    local current="$1" total="$2" label="$3"
    local width=28 filled percent

    ((total > 0)) || return 0
    percent=$((current * 100 / total))
    filled=$((current * width / total))

    if [[ -t 1 ]]; then
        printf '\r  %s%s%s %3d%%  %s' \
            "$C_CYAN" \
            "$(printf '%*s' "$filled" '' | tr ' ' '#')$(printf '%*s' "$((width - filled))" '' | tr ' ' '.')" \
            "$C_RESET" "$percent" "$label"
        ((current == total)) && printf '\n'
    elif ((current == total)); then
        printf '  %s complete\n' "$label"
    fi
}

cleanup() {
    printf '%s' "$C_SHOW_CURSOR"
    if [[ -n "$YAY_BUILD_DIR" && -d "$YAY_BUILD_DIR" ]]; then
        rm -rf -- "$YAY_BUILD_DIR"
    fi
}
trap cleanup EXIT

check_system() {
    if [[ "$EUID" -eq 0 ]]; then
        error "Do not run this script as root."
        exit 1
    fi

    if [[ ! -r /etc/os-release ]]; then
        error "Cannot determine the operating system."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${ID:-}" != "arch" && "${ID_LIKE:-}" != *arch* ]]; then
        error "This installer is intended for Arch-compatible distributions."
        error "Detected: ${PRETTY_NAME:-unknown}"
        exit 1
    fi

    for command_name in sudo pacman git; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            error "$command_name is required before running the installer."
            exit 1
        fi
    done

    if [[ ! -d "$PACKAGE_DIR" ]]; then
        error "Package manifest directory not found: $PACKAGE_DIR"
        exit 1
    fi

    local resolved_config_dir
    resolved_config_dir="$(readlink -m -- "$CONFIG_DIR")"
    if [[ -z "$resolved_config_dir" || "$resolved_config_dir" == "/" || "$resolved_config_dir" == "$HOME" ]]; then
        error "Refusing to use an unsafe configuration directory: $CONFIG_DIR"
        exit 1
    fi

    local resolved_repo_dir
    resolved_repo_dir="$(readlink -m -- "$REPO_DIR")"
    if [[ "$resolved_config_dir" == "$resolved_repo_dir" \
        || "$resolved_config_dir" == "$resolved_repo_dir/"* \
        || "$resolved_repo_dir" == "$resolved_config_dir/"* ]]; then
        error "The configuration directory and repository must not overlap."
        exit 1
    fi

    info "Detected distribution: ${PRETTY_NAME:-unknown}"
    sudo -v || exit 1
}

detect_graphics_hardware() {
    info "Detecting graphics hardware..."

    local device_path class_code vendor_id device_id boot_vga pci_address
    local igpu_boot_vga="0"

    for device_path in /sys/bus/pci/devices/*; do
        [[ -r "$device_path/class" && -r "$device_path/vendor" ]] || continue

        class_code="$(<"$device_path/class")"
        [[ "$class_code" == 0x03* ]] || continue

        vendor_id="$(<"$device_path/vendor")"
        device_id="$(<"$device_path/device")"
        boot_vga="0"
        [[ -r "$device_path/boot_vga" ]] && boot_vga="$(<"$device_path/boot_vga")"
        pci_address="$(basename "$device_path")"

        if [[ "$vendor_id" == "0x10de" ]]; then
            if [[ -z "$NVIDIA_PCI_ADDRESS" ]]; then
                NVIDIA_PCI_ADDRESS="$pci_address"
                NVIDIA_DEVICE_ID="$device_id"
            fi
            continue
        fi

        [[ "$vendor_id" == "0x8086" || "$vendor_id" == "0x1002" ]] || continue

        # Prefer the non-NVIDIA display controller marked as boot VGA. On the
        # target Intel/NVIDIA laptop this is the iGPU connected to the panel.
        if [[ -z "$IGPU_PCI_ADDRESS" || ("$boot_vga" == "1" && "$igpu_boot_vga" != "1") ]]; then
            IGPU_PCI_ADDRESS="$pci_address"
            IGPU_VENDOR_ID="$vendor_id"
            igpu_boot_vga="$boot_vga"
        fi
    done

    if [[ -n "$IGPU_PCI_ADDRESS" ]]; then
        info "Integrated/primary GPU: $IGPU_PCI_ADDRESS ($IGPU_VENDOR_ID)"
    else
        warning "No non-NVIDIA primary GPU was detected. Automatic GPU priority will be skipped."
    fi

    if [[ -n "$NVIDIA_PCI_ADDRESS" ]]; then
        info "NVIDIA GPU: $NVIDIA_PCI_ADDRESS ($NVIDIA_DEVICE_ID)"
    else
        info "No NVIDIA GPU detected."
    fi
}

select_nvidia_driver_package() {
    local installed_kernels=()
    local kernel_package

    for kernel_package in linux linux-lts linux-zen linux-hardened; do
        if pacman -Qq "$kernel_package" >/dev/null 2>&1; then
            installed_kernels+=("$kernel_package")
        fi
    done

    if [[ "${#installed_kernels[@]}" -eq 1 && "${installed_kernels[0]}" == "linux" ]]; then
        NVIDIA_DRIVER_PACKAGE="nvidia-open"
        return
    fi

    if [[ "${#installed_kernels[@]}" -eq 1 && "${installed_kernels[0]}" == "linux-lts" ]]; then
        NVIDIA_DRIVER_PACKAGE="nvidia-open-lts"
        return
    fi

    NVIDIA_DRIVER_PACKAGE="nvidia-open-dkms"
    for kernel_package in "${installed_kernels[@]}"; do
        PACKAGES+=("${kernel_package}-headers")
    done

    if [[ "${#installed_kernels[@]}" -eq 0 ]]; then
        warning "Could not identify an installed Arch kernel package; NVIDIA DKMS will require matching kernel headers."
    fi
}

detect_cpu_vendor() {
    if [[ -r /proc/cpuinfo ]]; then
        CPU_VENDOR="$(awk -F': ' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo)"
    fi

    case "$CPU_VENDOR" in
        GenuineIntel) info "CPU vendor: Intel" ;;
        AuthenticAMD) info "CPU vendor: AMD" ;;
        *) info "CPU vendor: unknown (${CPU_VENDOR:-unreported})" ;;
    esac
}

add_power_packages() {
    # thermald only implements Intel's thermal interfaces, so it is added by
    # detection rather than by manifest.
    if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
        PACKAGES+=(thermald)
    fi
}

add_graphics_packages() {
    # Diagnostic tools are useful on every graphics stack and let verification
    # report both the default renderer and PRIME offload renderer.
    PACKAGES+=(mesa mesa-utils vulkan-tools pciutils)

    case "$IGPU_VENDOR_ID" in
        0x8086)
            PACKAGES+=(intel-media-driver vulkan-intel)
            ;;
        0x1002)
            PACKAGES+=(libva-mesa-driver vulkan-radeon)
            ;;
    esac

    if [[ -n "$NVIDIA_PCI_ADDRESS" ]]; then
        PACKAGES+=(nvidia-utils nvidia-prime)

        # 10de:2860 is the confirmed Ada-generation RTX 4070 Laptop GPU.
        if [[ "$NVIDIA_DEVICE_ID" == "0x2860" ]]; then
            select_nvidia_driver_package
            PACKAGES+=("$NVIDIA_DRIVER_PACKAGE")
        else
            warning "Unknown NVIDIA device $NVIDIA_DEVICE_ID; no kernel driver package was selected automatically."
            ((INSTALL_FAILURES += 1))
        fi
    fi

    mapfile -t PACKAGES < <(printf '%s\n' "${PACKAGES[@]}" | sort -u)
}

update_system() {
    info "Updating the Arch package databases and installed packages..."
    if sudo pacman -Syu --noconfirm; then
        success "System update complete."
    else
        error "The system update failed; package installation cannot continue safely."
        exit 1
    fi
}

detect_aur_helper() {
    if command -v paru >/dev/null 2>&1; then
        AUR_HELPER="paru"
    elif command -v yay >/dev/null 2>&1; then
        AUR_HELPER="yay"
    fi

    if [[ -n "$AUR_HELPER" ]]; then
        info "AUR helper available: $AUR_HELPER"
        return
    fi

    info "No AUR helper found; bootstrapping yay..."
    if ! sudo pacman -S --needed --noconfirm git base-devel; then
        warning "Could not install the tools required to build yay."
        ((INSTALL_FAILURES += 1))
        return
    fi

    YAY_BUILD_DIR="$(mktemp -d)"
    if git clone https://aur.archlinux.org/yay.git "$YAY_BUILD_DIR/yay" \
        && (cd "$YAY_BUILD_DIR/yay" && makepkg -si --noconfirm); then
        AUR_HELPER="yay"
        success "yay installed."
    else
        warning "Failed to build yay. AUR packages will be reported as unresolved."
        ((INSTALL_FAILURES += 1))
    fi
}

load_packages() {
    local package_files=()
    mapfile -t package_files < <(
        find "$PACKAGE_DIR" -maxdepth 1 -type f -name '*.txt' -print | sort
    )

    if [[ "${#package_files[@]}" -eq 0 ]]; then
        error "No package manifests were found in $PACKAGE_DIR."
        exit 1
    fi

    mapfile -t PACKAGES < <(
        awk '!/^[[:space:]]*(#|$)/ { print $1 }' "${package_files[@]}" | sort -u
    )

    if [[ "${#PACKAGES[@]}" -eq 0 ]]; then
        error "The package manifests do not contain any packages."
        exit 1
    fi
}

resolve_packages() {
    info "Resolving ${#PACKAGES[@]} packages..."

    # Every AUR lookup is a network round trip, so this loop is slow and
    # otherwise silent. Draw a bar so it never looks like a hang.
    local package_name
    local resolved=0
    local total="${#PACKAGES[@]}"

    printf '%s' "$C_HIDE_CURSOR"
    for package_name in "${PACKAGES[@]}"; do
        if pacman -Si "$package_name" >/dev/null 2>&1; then
            OFFICIAL_PACKAGES+=("$package_name")
        elif [[ -n "$AUR_HELPER" ]] && "$AUR_HELPER" -Si "$package_name" >/dev/null 2>&1; then
            AUR_PACKAGES+=("$package_name")
        else
            UNKNOWN_PACKAGES+=("$package_name")
        fi

        ((resolved += 1))
        progress_bar "$resolved" "$total" "$resolved/$total  $package_name"
    done
    printf '%s' "$C_SHOW_CURSOR"

    info "Resolved ${#OFFICIAL_PACKAGES[@]} official, ${#AUR_PACKAGES[@]} AUR, ${#UNKNOWN_PACKAGES[@]} unresolved."
}

install_packages() {
    if [[ "${#OFFICIAL_PACKAGES[@]}" -gt 0 ]]; then
        info "Installing official repository packages..."
        if sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"; then
            success "Official packages installed."
        else
            warning "pacman failed to install one or more packages."
            ((INSTALL_FAILURES += 1))
        fi
    fi

    if [[ "${#AUR_PACKAGES[@]}" -gt 0 ]]; then
        if [[ -n "$AUR_HELPER" ]]; then
            info "Installing AUR packages with $AUR_HELPER..."
            if "$AUR_HELPER" -S --needed --noconfirm "${AUR_PACKAGES[@]}"; then
                success "AUR packages installed."
            else
                warning "$AUR_HELPER failed to install one or more packages."
                ((INSTALL_FAILURES += 1))
            fi
        else
            UNKNOWN_PACKAGES+=("${AUR_PACKAGES[@]}")
        fi
    fi

    if [[ "${#UNKNOWN_PACKAGES[@]}" -gt 0 ]]; then
        warning "Unresolved packages: ${UNKNOWN_PACKAGES[*]}"
        ((INSTALL_FAILURES += 1))
    fi
}

create_backup_dir() {
    if [[ "$BACKUP_CREATED" == false ]]; then
        mkdir -p "$BACKUP_DIR"
        BACKUP_CREATED=true
    fi
}

backup_existing_configs() {
    info "Checking for existing configuration to back up..."

    mkdir -p "$CONFIG_DIR"

    local source_item name
    for source_item in "$REPO_DIR/.config/"*; do
        [[ -e "$source_item" || -L "$source_item" ]] || continue
        name="$(basename "$source_item")"

        if [[ -e "$CONFIG_DIR/$name" || -L "$CONFIG_DIR/$name" ]]; then
            create_backup_dir
            cp -a -- "$CONFIG_DIR/$name" "$BACKUP_DIR/"
        fi
    done

    if [[ -e "$HOME/.zshrc" || -L "$HOME/.zshrc" ]]; then
        create_backup_dir
        cp -a -- "$HOME/.zshrc" "$BACKUP_DIR/.zshrc"
    fi

    if [[ "$BACKUP_CREATED" == true ]]; then
        success "Existing configuration backed up to $BACKUP_DIR"
    else
        info "No existing managed configuration needed a backup."
    fi
}

install_dotfiles() {
    info "Installing dotfiles using the copy deployment model..."

    # Replace each top-level managed item instead of merging directories. The
    # backup above retains the old version, and this prevents files removed
    # from the repository from lingering in the live configuration forever.
    local source_item name
    for source_item in "$REPO_DIR/.config/"*; do
        [[ -e "$source_item" || -L "$source_item" ]] || continue
        name="$(basename "$source_item")"
        rm -rf -- "$CONFIG_DIR/$name"
        cp -a -- "$source_item" "$CONFIG_DIR/$name"
    done

    # Machine-local files are intentionally absent from Git. Preserve them
    # across a reinstall; generated files may be refreshed later when hardware
    # detection runs, while hand-edited files are left untouched.
    local local_file
    for local_file in hypr/machine.lua hypr/gpu/local.lua hypr/hyprland-gui.lua; do
        if [[ -e "$BACKUP_DIR/$local_file" || -L "$BACKUP_DIR/$local_file" ]]; then
            mkdir -p "$(dirname "$CONFIG_DIR/$local_file")"
            cp -a -- "$BACKUP_DIR/$local_file" "$CONFIG_DIR/$local_file"
        fi
    done

    rm -f -- "$HOME/.zshrc"
    cp -a -- "$REPO_DIR/.zshrc" "$HOME/.zshrc"

    local script_dir
    for script_dir in \
        "$CONFIG_DIR/hypr/scripts" \
        "$CONFIG_DIR/quickshell/hyprquickpaper" \
        "$CONFIG_DIR/waybar/scripts" \
        "$CONFIG_DIR/themes"; do
        if [[ -d "$script_dir" ]]; then
            find "$script_dir" -maxdepth 1 -type f -name '*.sh' -exec chmod +x {} +
        fi
    done

    success "Dotfiles installed."
}

prepare_hyprmod_config() {
    local hyprmod_file="$CONFIG_DIR/hypr/hyprland-gui.lua"

    if [[ -e "$hyprmod_file" || -L "$hyprmod_file" ]]; then
        return
    fi

    # HyprMod owns this ignored file. Creating it ahead of first launch lets
    # its config discovery follow the require() in hyprland.lua immediately.
    {
        printf '%s\n' '-- Managed by HyprMod; intentionally not tracked by Git.'
        printf '%s\n' '-- Use Super + / to open the graphical settings editor.'
    } >"$hyprmod_file"
}

install_gpu_alias_rules() {
    if [[ -z "$IGPU_PCI_ADDRESS" ]]; then
        return
    fi

    info "Creating stable DRM device aliases..."

    local rule_path="/etc/udev/rules.d/90-dotfiles-hyprland-gpus.rules"
    local temporary_file
    temporary_file="$(mktemp)" || {
        warning "Could not create a temporary udev rules file."
        ((INSTALL_FAILURES += 1))
        return
    }

    {
        printf '%s\n' '# Generated by the personal dotfiles installer.'
        printf 'SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="%s", SYMLINK+="dri/hyprland-igpu"\n' \
            "$IGPU_PCI_ADDRESS"

        if [[ -n "$NVIDIA_PCI_ADDRESS" ]]; then
            printf 'SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="%s", SYMLINK+="dri/hyprland-nvidia"\n' \
                "$NVIDIA_PCI_ADDRESS"
        fi
    } >"$temporary_file"

    if sudo install -Dm644 "$temporary_file" "$rule_path"; then
        sudo udevadm control --reload-rules
        sudo udevadm trigger --subsystem-match=drm || true
        success "Stable DRM aliases configured."
    else
        warning "Could not install the DRM alias rules."
        ((INSTALL_FAILURES += 1))
    fi

    rm -f -- "$temporary_file"
}

write_gpu_config() {
    if [[ -z "$IGPU_PCI_ADDRESS" ]]; then
        return
    fi

    local gpu_dir="$CONFIG_DIR/hypr/gpu"
    local gpu_file="$gpu_dir/local.lua"
    local generated_marker="-- Generated automatically by the dotfiles hardware detector."
    local temporary_file

    if [[ -f "$gpu_file" ]] && ! grep -Fqx -- "$generated_marker" "$gpu_file"; then
        warning "Keeping hand-edited GPU configuration: $gpu_file"
        return
    fi

    mkdir -p "$gpu_dir"
    temporary_file="$(mktemp "$gpu_dir/.local.lua.XXXXXX")" || {
        warning "Could not create the local GPU configuration."
        ((INSTALL_FAILURES += 1))
        return
    }

    {
        printf '%s\n' "$generated_marker"
        printf '%s\n' 'return {'
        printf '%s\n' '    "/dev/dri/hyprland-igpu",'
        if [[ -n "$NVIDIA_PCI_ADDRESS" ]]; then
            printf '%s\n' '    "/dev/dri/hyprland-nvidia",'
        fi
        printf '%s\n' '}'
    } >"$temporary_file"

    mv -f -- "$temporary_file" "$gpu_file"
}

detect_internal_display() {
    local connector_path connector_name status resolution

    for connector_path in \
        /sys/class/drm/card*-eDP-* \
        /sys/class/drm/card*-LVDS-* \
        /sys/class/drm/card*-DSI-*; do
        [[ -d "$connector_path" && -r "$connector_path/status" ]] || continue
        status="$(<"$connector_path/status")"
        [[ "$status" == "connected" ]] || continue

        connector_name="$(basename "$connector_path")"
        INTERNAL_OUTPUT="${connector_name#*-}"

        if [[ -r "$connector_path/modes" ]]; then
            read -r resolution <"$connector_path/modes" || true
            if [[ "$resolution" =~ ^[0-9]+x[0-9]+$ ]]; then
                INTERNAL_RESOLUTION="$resolution"
            fi
        fi
        return
    done
}

write_monitor_config() {
    detect_internal_display

    if [[ -z "$INTERNAL_OUTPUT" ]]; then
        info "The internal DRM connector is not available yet; first Hyprland launch will detect it."
        return
    fi

    local machine_file="$CONFIG_DIR/hypr/machine.lua"
    local generated_marker="-- Generated automatically by the dotfiles hardware detector."
    local scale=1
    local width=0
    local height=0
    local temporary_file

    if [[ -f "$machine_file" ]] && ! grep -Fqx -- "$generated_marker" "$machine_file"; then
        warning "Keeping hand-edited monitor configuration: $machine_file"
        return
    fi

    if [[ "$INTERNAL_RESOLUTION" =~ ^([0-9]+)x([0-9]+)$ ]]; then
        width="${BASH_REMATCH[1]}"
        height="${BASH_REMATCH[2]}"
    fi

    if ((width >= 3000 && height >= 1800)); then
        scale=2
    elif ((width >= 2500 || height >= 1400)); then
        scale=1.5
    fi

    temporary_file="$(mktemp "$CONFIG_DIR/hypr/.machine.lua.XXXXXX")" || {
        warning "Could not create the machine-local monitor configuration."
        ((INSTALL_FAILURES += 1))
        return
    }

    {
        printf '%s\n' "$generated_marker"
        printf '%s\n' 'return {'
        printf '%s\n' '    monitors = {'
        printf '%s\n' '        {'
        printf '            output = "%s",\n' "$INTERNAL_OUTPUT"
        printf '%s\n' '            mode = "preferred",'
        printf '%s\n' '            position = "0x0",'
        printf '            scale = %s,\n' "$scale"
        printf '%s\n' '        },'
        printf '%s\n' '    },'
        printf '%s\n' '}'
    } >"$temporary_file"

    mv -f -- "$temporary_file" "$machine_file"
    success "Internal display detected as $INTERNAL_OUTPUT (${INTERNAL_RESOLUTION:-preferred})."
}

configure_graphics() {
    install_gpu_alias_rules
    write_gpu_config
    write_monitor_config

    if [[ -n "$IGPU_PCI_ADDRESS" && -n "$NVIDIA_PCI_ADDRESS" ]]; then
        HARDWARE_CONFIGURATION="Intel/AMD iGPU first, NVIDIA available for outputs and PRIME"
    elif [[ -n "$IGPU_PCI_ADDRESS" ]]; then
        HARDWARE_CONFIGURATION="integrated GPU"
    else
        HARDWARE_CONFIGURATION="automatic fallback"
    fi
}

install_wallpapers() {
    if [[ ! -d "$REPO_DIR/Wallpapers" ]]; then
        return
    fi

    info "Installing wallpapers..."
    mkdir -p "$HOME/Pictures/Wallpapers"
    cp -a -- "$REPO_DIR/Wallpapers/." "$HOME/Pictures/Wallpapers/"
    success "Wallpapers installed."
}

configure_services() {
    if ! command -v systemctl >/dev/null 2>&1; then
        warning "systemctl is unavailable; services were not configured."
        ((INSTALL_FAILURES += 1))
        return
    fi

    info "Enabling system services..."
    if ! sudo systemctl enable --now NetworkManager.service; then
        warning "NetworkManager could not be enabled."
        ((INSTALL_FAILURES += 1))
    fi

    if ! sudo systemctl enable --now bluetooth.service; then
        warning "Bluetooth could not be enabled."
        ((INSTALL_FAILURES += 1))
    fi

    info "Enabling PipeWire user services..."
    if ! systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service; then
        warning "One or more PipeWire user services could not be enabled."
        ((INSTALL_FAILURES += 1))
    fi
}

configure_power() {
    if ! command -v systemctl >/dev/null 2>&1; then
        warning "systemctl is unavailable; power management was not configured."
        ((INSTALL_FAILURES += 1))
        return
    fi

    info "Configuring power management..."

    # power-profiles-daemon is the conservative baseline. TLP is intentionally
    # not installed: both tools drive the same kernel tunables and overwrite
    # each other. https://linrunner.de/tlp/faq/ppd.html
    if systemctl list-unit-files power-profiles-daemon.service >/dev/null 2>&1; then
        if sudo systemctl enable --now power-profiles-daemon.service; then
            success "power-profiles-daemon enabled."
        else
            warning "power-profiles-daemon could not be enabled."
            ((INSTALL_FAILURES += 1))
        fi
    fi

    # Let the daemon swap profiles on AC/battery transitions by itself where
    # the installed version supports it.
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl configure-battery-aware --enable >/dev/null 2>&1 \
            || info "This power-profiles-daemon build has no battery-aware switching; the session watcher still handles the display."
    fi

    if [[ "$CPU_VENDOR" == "GenuineIntel" ]] \
        && systemctl list-unit-files thermald.service >/dev/null 2>&1; then
        if sudo systemctl enable --now thermald.service; then
            success "thermald enabled for Intel thermal management."
        else
            warning "thermald could not be enabled."
            ((INSTALL_FAILURES += 1))
        fi
    fi

    if [[ -n "$NVIDIA_PCI_ADDRESS" ]]; then
        # The NVIDIA packages ship these units but do not enable them. Without
        # them, video memory is not saved and restored across suspend.
        local unit
        for unit in nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service; do
            if systemctl list-unit-files "$unit" >/dev/null 2>&1; then
                sudo systemctl enable "$unit" >/dev/null 2>&1 \
                    || warning "$unit could not be enabled."
            fi
        done

        # Runtime D3 is left at the driver default. NVreg_DynamicPowerManagement
        # defaults to 0x03, which the driver documents as fine-grained power
        # control on Ampere-and-newer notebooks, and the driver already ships
        # /lib/udev/rules.d/80-nvidia-pm.rules. Forcing 0x02 here would add risk
        # without adding capability; verify_power reports the live state instead.
        info "NVIDIA runtime power management left at the driver default (fine-grained on this GPU generation)."
    fi
}

configure_desktop() {
    if command -v papirus-folders >/dev/null 2>&1; then
        papirus-folders -C white || warning "Could not set the Papirus folder color."
    fi

    local zen_desktop=""
    if command -v pacman >/dev/null 2>&1; then
        zen_desktop="$(
            pacman -Qlq zen-browser-bin 2>/dev/null \
                | awk -F/ '/share\/applications\/.*\.desktop$/ { print $NF; exit }'
        )"
    fi

    if [[ -n "$zen_desktop" ]] && command -v xdg-mime >/dev/null 2>&1; then
        xdg-mime default "$zen_desktop" x-scheme-handler/http
        xdg-mime default "$zen_desktop" x-scheme-handler/https
        xdg-mime default "$zen_desktop" text/html
    elif [[ -z "$zen_desktop" ]]; then
        warning "Could not determine Zen Browser's desktop-file ID; the default browser was not changed."
        ((INSTALL_FAILURES += 1))
    fi

    if [[ -n "$zen_desktop" ]] && command -v xdg-settings >/dev/null 2>&1; then
        xdg-settings set default-web-browser "$zen_desktop" >/dev/null 2>&1 || true
    fi

    if [[ -x "$CONFIG_DIR/themes/apply.sh" ]]; then
        "$CONFIG_DIR/themes/apply.sh" monochrome-dark || warning "Initial theme application failed."
    fi
}

setup_nvchad() {
    local nvim_dir="$CONFIG_DIR/nvim"

    if [[ -e "$nvim_dir" || -L "$nvim_dir" ]]; then
        warning "Neovim configuration already exists; NvChad bootstrap was skipped: $nvim_dir"
        return
    fi

    info "Installing the official NvChad starter configuration..."
    if git clone --depth 1 https://github.com/NvChad/starter "$nvim_dir"; then
        rm -rf -- "$nvim_dir/.git"
        success "NvChad starter installed."
    else
        warning "NvChad starter could not be cloned."
        ((INSTALL_FAILURES += 1))
    fi
}

setup_development_tools() {
    if ! command -v rustup >/dev/null 2>&1; then
        warning "rustup is unavailable; the Rust stable toolchain was not configured."
        ((INSTALL_FAILURES += 1))
        return
    fi

    info "Configuring the Rust stable toolchain..."
    if ! rustup default stable; then
        warning "rustup could not install or select the stable toolchain."
        ((INSTALL_FAILURES += 1))
        return
    fi

    if rustup component add rust-analyzer rust-src rustfmt clippy; then
        success "Rust stable toolchain and editor components configured."
    else
        warning "Rust is installed, but one or more development components could not be added."
        ((INSTALL_FAILURES += 1))
    fi
}

verify_command() {
    local label="$1"
    local command_name="$2"

    if command -v "$command_name" >/dev/null 2>&1; then
        printf '  %-22s OK\n' "$label"
    else
        printf '  %-22s MISSING (%s)\n' "$label" "$command_name"
        ((VERIFY_FAILURES += 1))
    fi
}

verify_install() {
    info "Verifying required commands..."

    verify_command "Hyprland" Hyprland
    verify_command "Waybar" waybar
    verify_command "Rofi" rofi
    verify_command "Quickshell" quickshell
    verify_command "Hyprlock" hyprlock
    verify_command "Wlogout" wlogout
    verify_command "Zen Browser" zen-browser
    verify_command "Brave" brave
    verify_command "Kitty" kitty
    verify_command "Thunar" thunar
    verify_command "Zed" zeditor
    verify_command "Helix" hx
    verify_command "Neovim" nvim
    verify_command "Python" python
    verify_command "pip" pip
    verify_command "uv" uv
    verify_command "Rust compiler" rustc
    verify_command "Cargo" cargo
    verify_command "rust-analyzer" rust-analyzer
    verify_command "rustfmt" rustfmt
    verify_command "Clippy" cargo-clippy
    verify_command "Go" go
    verify_command "gopls" gopls
    verify_command "Node.js" node
    verify_command "npm" npm
    verify_command "TypeScript" tsc
    verify_command "TypeScript LSP" typescript-language-server
    verify_command "Pyright" pyright
    verify_command "GCC" gcc
    verify_command "G++" g++
    verify_command "Clang" clang
    verify_command "Make" make
    verify_command "CMake" cmake
    verify_command "Ninja" ninja
    verify_command "pkg-config" pkg-config
    verify_command "GDB" gdb
    verify_command "LLDB" lldb
    verify_command "ShellCheck" shellcheck
    verify_command "shfmt" shfmt
    verify_command "Fish" fish
    verify_command "Zsh" zsh
    verify_command "Starship" starship
    verify_command "Clipboard history" cliphist
    verify_command "Wallpaper daemon" awww
    verify_command "Wallpaper colors" matugen
    verify_command "Notifications" dunst
    verify_command "HyprMod" hyprmod
    verify_command "Power profiles" powerprofilesctl

    if [[ -n "$NVIDIA_PCI_ADDRESS" ]]; then
        verify_command "NVIDIA utility" nvidia-smi
        verify_command "PRIME launcher" prime-run
    fi

    if [[ ! -x /usr/lib/polkit-kde-authentication-agent-1 ]]; then
        printf '  %-22s MISSING\n' "Polkit agent"
        ((VERIFY_FAILURES += 1))
    else
        printf '  %-22s OK\n' "Polkit agent"
    fi

    if systemctl is-enabled NetworkManager.service >/dev/null 2>&1; then
        printf '  %-22s OK\n' "NetworkManager service"
    else
        printf '  %-22s NOT ENABLED\n' "NetworkManager service"
        ((VERIFY_FAILURES += 1))
    fi

    verify_power
}

verify_power() {
    local unit

    for unit in power-profiles-daemon.service thermald.service; do
        systemctl list-unit-files "$unit" >/dev/null 2>&1 || continue
        if systemctl is-enabled "$unit" >/dev/null 2>&1; then
            printf '  %-22s OK\n' "${unit%.service}"
        else
            printf '  %-22s NOT ENABLED\n' "${unit%.service}"
            ((VERIFY_FAILURES += 1))
        fi
    done

    # TLP and power-profiles-daemon overwrite each other's kernel tunables.
    if systemctl is-enabled tlp.service >/dev/null 2>&1; then
        warning "tlp.service is enabled alongside power-profiles-daemon. Disable one; they conflict."
        ((VERIFY_FAILURES += 1))
    fi

    if [[ -n "$NVIDIA_PCI_ADDRESS" ]]; then
        local power_file="/proc/driver/nvidia/gpus/$NVIDIA_PCI_ADDRESS/power"
        if [[ -r "$power_file" ]]; then
            printf '  %-22s %s\n' "NVIDIA runtime D3" \
                "$(awk -F': ' '/Runtime D3 status/ { print $2; exit }' "$power_file")"
        else
            printf '  %-22s reboot required\n' "NVIDIA runtime D3"
        fi
    fi

    local battery found=false
    for battery in /sys/class/power_supply/BAT*; do
        [[ -r "$battery/capacity" ]] || continue
        found=true
        printf '  %-22s %s%% (%s)\n' "Battery $(basename "$battery")" \
            "$(<"$battery/capacity")" "$(<"$battery/status")"
    done
    [[ "$found" == false ]] && printf '  %-22s none detected\n' "Battery"
}

print_summary() {
    printf '\n%s========================================%s\n' "$C_GREEN" "$C_RESET"
    printf '%s      Personal Hyprland Setup Ready     %s\n' "$C_GREEN" "$C_RESET"
    printf '%s========================================%s\n\n' "$C_GREEN" "$C_RESET"
    printf 'Total time:    %s\n' "$(format_duration "$((SECONDS - START_TIME))")"
    printf 'Distribution:  %s\n' "${PRETTY_NAME:-unknown}"
    printf 'AUR helper:    %s\n' "${AUR_HELPER:-none}"
    printf 'Configuration: %s\n' "$CONFIG_DIR"
    printf 'Deployment:    copy\n'
    printf 'Browser:       Zen Browser\n'
    printf 'Theme:         monochrome-dark\n'
    printf 'Shortcut GUI:  HyprMod (Super + /)\n'
    printf 'Power manager: power-profiles-daemon%s\n' \
        "$([[ "$CPU_VENDOR" == "GenuineIntel" ]] && printf ' + thermald')"
    printf 'Graphics:      %s\n' "$HARDWARE_CONFIGURATION"

    if [[ -n "$NVIDIA_DRIVER_PACKAGE" ]]; then
        printf 'NVIDIA driver: %s\n' "$NVIDIA_DRIVER_PACKAGE"
    fi

    if [[ -n "$INTERNAL_OUTPUT" ]]; then
        printf 'Internal panel: %s (%s)\n' "$INTERNAL_OUTPUT" "${INTERNAL_RESOLUTION:-preferred}"
    else
        printf 'Internal panel: deferred to first Hyprland launch\n'
    fi

    if [[ "$BACKUP_CREATED" == true ]]; then
        printf 'Backup:        %s\n' "$BACKUP_DIR"
    fi

    printf '\nNext steps:\n'
    printf '  1. Start nvim, wait for plugins, then run :MasonInstallAll and :TSInstallAll.\n'
    if [[ -n "$NVIDIA_DRIVER_PACKAGE" ]]; then
        printf '  2. Reboot so the NVIDIA kernel module and stable DRM aliases are active.\n'
        printf '  3. Start Hyprland; display detection will finish automatically.\n'
    else
        printf '  2. Start Hyprland; display detection will finish automatically.\n'
    fi

    if (( INSTALL_FAILURES > 0 || VERIFY_FAILURES > 0 )); then
        warning "Installation completed with $INSTALL_FAILURES installation issue(s) and $VERIFY_FAILURES verification failure(s)."
        return 1
    fi

    success "Installation and verification completed successfully."
}

main() {
    local -a phases=(
        "Checking the system:check_system"
        "Updating the system:update_system"
        "Detecting graphics hardware:detect_graphics_hardware"
        "Detecting the CPU:detect_cpu_vendor"
        "Preparing the AUR helper:detect_aur_helper"
        "Reading package manifests:load_packages"
        "Selecting graphics packages:add_graphics_packages"
        "Selecting power packages:add_power_packages"
        "Resolving packages:resolve_packages"
        "Installing packages:install_packages"
        "Backing up existing configuration:backup_existing_configs"
        "Installing dotfiles:install_dotfiles"
        "Preparing HyprMod:prepare_hyprmod_config"
        "Configuring graphics:configure_graphics"
        "Installing wallpapers:install_wallpapers"
        "Enabling services:configure_services"
        "Configuring power management:configure_power"
        "Configuring the desktop:configure_desktop"
        "Setting up development tools:setup_development_tools"
        "Installing NvChad:setup_nvchad"
        "Verifying the installation:verify_install"
    )

    PHASE_TOTAL="${#phases[@]}"
    START_TIME="$SECONDS"

    local phase
    for phase in "${phases[@]}"; do
        run_phase "${phase%%:*}" "${phase##*:}"
    done

    print_summary
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
