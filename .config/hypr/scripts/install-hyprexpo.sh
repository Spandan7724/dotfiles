#!/usr/bin/env bash

set -euo pipefail

repository="https://github.com/sandwichfarm/hyprexpo.git"
target="$HOME/.local/lib/hyprland-plugins/hyprexpo.so"
metadata="$HOME/.local/lib/hyprland-plugins/hyprexpo.hyprland-commit"
build_dir=""

cleanup() {
    [[ -z "$build_dir" ]] || rm -rf -- "$build_dir"
}
trap cleanup EXIT

for command_name in Hyprland git make g++ python pkg-config install; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    fi
done

hyprland_commit="$(Hyprland --version 2>/dev/null | sed -nE 's/.*commit ([0-9a-f]{40}).*/\1/p' | head -n 1)"
if [[ -z "$hyprland_commit" ]]; then
    printf 'Could not determine the installed Hyprland commit.\n' >&2
    exit 1
fi

if [[ -r "$target" && -r "$metadata" ]] \
    && [[ "$(<"$metadata")" == "$hyprland_commit" ]] \
    && [[ "${1:-}" != "--force" ]]; then
    printf 'HyprExpo already matches Hyprland %s.\n' "$hyprland_commit"
    exit 0
fi

build_dir="$(mktemp -d)" || exit 1
git clone --depth 1 "$repository" "$build_dir"

plugin_commit="$(python - "$build_dir/hyprpm.toml" "$hyprland_commit" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as source:
    data = tomllib.load(source)

for hyprland, plugin in data["repository"]["commit_pins"]:
    if hyprland == sys.argv[2]:
        print(plugin)
        break
PY
)"

if [[ -z "$plugin_commit" ]]; then
    printf 'HyprExpo has no compatibility pin for Hyprland %s.\n' "$hyprland_commit" >&2
    exit 1
fi

git -C "$build_dir" fetch --depth 1 origin "$plugin_commit"
git -C "$build_dir" checkout --detach "$plugin_commit"
make -C "$build_dir" -j"$(nproc)" all
install -Dm755 "$build_dir/hyprexpo.so" "$target"
printf '%s\n' "$hyprland_commit" >"$metadata"
printf 'Installed HyprExpo %s for Hyprland %s.\n' "$plugin_commit" "$hyprland_commit"
