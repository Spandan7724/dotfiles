# Personal Arch + Hyprland dotfiles

Personal floating-first Hyprland desktop configuration for a fresh Arch Linux
installation. Normal application windows float by default while fullscreen,
workspaces, keyboard navigation, and manual layout controls remain available.

The desktop stack uses Waybar, Rofi, Quickshell, Hyprlock, Wlogout, Dunst,
Kitty, Thunar, PipeWire, Fish or Zsh, Starship, and Matugen for
wallpaper-derived colors.

## Applications

- Default browser: Zen Browser
- Secondary browser: Brave
- Terminal: Kitty
- File manager: Thunar
- Graphical editor: Zed
- Terminal editors: Helix and Neovim with NvChad
- Shells: Fish and Zsh
- Prompt: Starship

## Preparing the Arch installation

Install Arch however you prefer; `archinstall` is the quickest route. Four
things have to be true before this repository's installer can run, and none of
them come from the `base` metapackage:

- A **user account with sudo access**. The installer refuses to run as root.
- **`sudo` installed.** `archinstall` adds it when you create a user with
  superuser privileges.
- **Working network at first boot.** Choose a network configuration such as
  NetworkManager during installation; everything else is downloaded.
- **`git` installed**, or install it with the first command below.

Do not pick a desktop profile. This repository installs Hyprland and the entire
desktop stack itself, and a preinstalled desktop only adds packages to conflict
with.

## Installation

Clone the repository and run the installer from inside it:

```bash
sudo pacman -S --needed git
git clone <repository-url> ~/code/dotfiles
cd ~/code/dotfiles
./install.sh
```

`install.sh` is not standalone. It reads the package manifests, configuration
tree, and wallpapers from the directory it lives in, so downloading the script
by itself will not work — it exits with `Package manifest directory not found`.

Requirements before running it:

- A booted Arch-compatible installation, not the live ISO.
- `sudo`, `pacman`, and `git` present. Everything else is installed for you,
  including `base-devel` and a `yay` bootstrap when no AUR helper exists.
- A normal user account. The script refuses to run as root and calls `sudo`
  only for the steps that need it.
- A working network connection.
- A clone location outside `~/.config`. The script refuses to run if the
  repository and the configuration directory overlap.

It does not need a graphical session. Running it from a TTY on a fresh install
is the expected path; start Hyprland afterwards.

What it does, in order: updates the system, detects graphics and CPU hardware,
finds or bootstraps an AUR helper, resolves and installs official and AUR
packages, backs up any managed configuration it is about to replace, installs
the dotfiles, configures graphics, installs the wallpapers, enables
NetworkManager, Bluetooth, and PipeWire, configures power management, sets Zen
as the default browser and applies the initial theme, sets up the Rust
toolchain, clones the official NvChad starter, then verifies the result and
prints a summary. HyprMod provides a graphical editor for Hyprland settings and
shortcuts.

Package resolution and installation are a hard gate: if any required official
or AUR package cannot be resolved or installed, the script exits before it
backs up or replaces configuration. Fix the reported package or network issue
and rerun it.

Nothing in the repository is needed at runtime — the deployment model is a
copy, so the desktop keeps working if the clone is deleted. Keep it anyway:
rerunning the installer is how you apply updates.

### Rerunning

The installer is safe to rerun. Managed configuration is backed up to
`~/.config-backups/<timestamp>/` and replaced rather than merged, so files you
deleted from the repository do not linger in the live configuration. The
machine-local files it generates — `hypr/machine.lua`, `hypr/gpu/local.lua`,
and HyprMod's `hypr/hyprland-gui.lua` — are preserved across reruns, and a
hand-edited local file is never overwritten.

Because the deployment is a copy, edits made directly in `~/.config` do not
flow back to the repository and will be replaced on the next run. Make changes
in the clone, or copy them back before rerunning. See the deployment model
section below.

Packages are organized under `packages/`:

- `base.txt`: installation and command-line foundations
- `desktop.txt`: Hyprland and desktop applications
- `dev.txt`: editors and NvChad prerequisites
- `optional.txt`: explicitly chosen optional software

The development group includes Python with `pip` and `uv`, Rust through
`rustup`, Go, Node.js with npm, GCC/G++, Clang, Make, CMake, Ninja, pkg-config,
GDB, LLDB, ShellCheck, and shfmt. The installer idempotently selects Rust's
stable toolchain and adds `rust-analyzer`, `rust-src`, rustfmt, and Clippy after
installing `rustup`. Pyright, gopls, TypeScript, and
typescript-language-server provide editor support without global npm installs.

## Shells

The installer does not force a login shell. Choose one after installation:

```bash
chsh -s /usr/bin/fish
```

or:

```bash
chsh -s /usr/bin/zsh
```

Both shells use the same active Starship theme.

## NvChad

The installer follows the official NvChad starter flow by cloning
`NvChad/starter` into `~/.config/nvim` when no Neovim configuration exists.
After installation:

1. Start `nvim` and wait for plugins to finish installing.
2. Run `:MasonInstallAll`.
3. Run `:TSInstallAll`.

An existing Neovim configuration is never overwritten.

## Coordinated themes

`Super + Shift + T` opens the theme selector. The initial profiles are:

- `monochrome-dark`
- `monochrome-light`

Switching profiles coordinates Kitty, Waybar, Rofi, Dunst, Hyprlock, Wlogout,
GTK 3/4, Starship, Zed, Helix, the system light/dark preference, the Papirus
icon variant, and the wallpaper. GTK uses its supported theme and
color-preference settings rather than global widget CSS overrides. The switcher
can also be run directly:

```bash
~/.config/themes/apply.sh monochrome-light
```

Each wallpaper change also runs Matugen in the active profile's light or dark
mode. It derives a Material color scheme from the image and generates color
fragments for Quickshell, Kitty, Waybar, Rofi, Dunst, Hyprlock, and Wlogout.
Quickshell watches its generated JSON palette and updates live; Kitty, Waybar,
and Dunst are signalled to reload; Rofi, Hyprlock, and Wlogout read the new
colors the next time they open. Tracked fallback files keep the desktop usable
before the first palette has been generated.

Each application is wired up in its own native mechanism rather than through a
generated monolith:

| Application | Profile fragment | Generated palette |
| --- | --- | --- |
| Kitty | `include` | `include colors.conf` |
| Waybar, Wlogout | GTK `@import` | `@import "colors.css"` |
| Rofi | `@import` | `@import "colors.rasi"` |
| Dunst | `dunstrc.d/50-theme.conf` drop-in | `dunstrc.d/90-colors.conf` drop-in |
| Hyprlock | `source =` | `source =` |
| Starship, Helix | symlink into `themes/current` | not recolored |
| Zed | system light/dark + local theme | not recolored |

Dunst reads `dunstrc.d/*.conf` in lexical order after the base `dunstrc` and
lets the later file win, so `50-theme.conf` carries the profile and
`90-colors.conf` carries the wallpaper palette. Hyprlock treats a `source=`
path that matches nothing as a fatal parse error, so both of its fragments are
tracked and always present.

The Wlogout button icons are white PNGs with no recolorable source, so its
buttons stay dark in the light profile while the scrim lightens. That keeps the
icons legible instead of washing them out.

To apply any wallpaper and its colors without changing the named profile:

```bash
~/.config/themes/wallpaper.sh "$HOME/Pictures/Wallpapers/wallpaper-01.png"
```

Zed, Helix, Starship, and GTK continue to follow the coordinated named
light/dark profile. Their editor syntax and widget themes deliberately remain
stable while the desktop chrome and terminal palette follow the wallpaper.
Already-running GTK applications may need to be restarted.

The theme implementation follows each application's native format:

- Kitty configuration fragments and reload signals: https://sw.kovidgoyal.net/kitty/conf/
- Waybar GTK CSS styling: https://github.com/Alexays/Waybar/blob/master/man/waybar.5.scd.in
- Rofi Rasi themes: https://davatorium.github.io/rofi/current/rofi-theme.5/
- GTK settings and system color preference: https://docs.gtk.org/gtk4/class.Settings.html
- Starship TOML schema and palettes: https://starship.rs/config/
- Zed local theme schema: https://zed.dev/docs/extensions/themes
- Helix theme scopes and palettes: https://docs.helix-editor.com/master/themes.html
- Matugen configuration and templates: https://github.com/InioX/matugen
- Quickshell watched files: https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/FileView/
- Dunst settings and drop-in directory: https://man.archlinux.org/man/dunst.5
- Hyprlock configuration: https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/

## Keybindings

| Keybinding | Action |
| --- | --- |
| `Super + T` | Open Kitty |
| `Super + D` | Toggle Rofi application launcher |
| `Super + E` | Open Thunar |
| `Super + B` | Open Zen Browser |
| `Super + Q` | Close active window |
| `Super + F` | Toggle fullscreen |
| `Super + Space` | Toggle floating and center at 70% size |
| `Super + O` | Select active-window opacity |
| `Super + W` | Open wallpaper selector |
| `Super + Shift + T` | Open coordinated theme selector |
| `Super + /` | Open HyprMod settings and shortcut editor |
| `Super + Shift + W` | Toggle Waybar |
| `Super + V` | Open clipboard history |
| `Super + Tab` | Lock with Hyprlock |
| `Super + Grave` | Open Wlogout |
| `Super + Shift + E` | Exit Hyprland |
| `Super + H/J/K/L` | Focus left/down/up/right |
| `Super + Shift + H/J/K/L` | Move window left/down/up/right |
| `Super + Ctrl + H/J/K/L` | Resize window |
| `Super + 1..0` | Switch to workspace 1–10 |
| `Super + Shift + 1..0` | Move window to workspace 1–10 |
| `Super + left mouse drag` | Move window |
| `Super + right mouse drag` | Resize window |
| `Super + mouse wheel` | Zoom compositor view |
| `Super + keypad -/+` | Zoom compositor view |
| `Super + Delete` | Screenshot the full output |
| `Delete` | Screenshot a selected region |
| `XF86MonBrightnessUp/Down` | Adjust brightness |
| `XF86AudioRaise/LowerVolume` | Adjust volume |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioPlay/Next/Previous` | Control media |

## Graphical shortcut management

`Super + /` opens HyprMod. Its Keybindings page can inspect, capture, add,
edit, and remove shortcuts using Hyprland's native Lua configuration format.

Repository defaults remain in `.config/hypr/keybinds.lua`. HyprMod writes its
changes to the ignored `~/.config/hypr/hyprland-gui.lua`, which is loaded after
the repository modules so its entries can act as local overrides. The installer
preserves this file across copy-based reinstalls. This separates personal GUI
changes from version-controlled defaults and makes removing all GUI overrides
as simple as deleting that one local file.

## Deployment model

The installer currently uses the copy model: repository files are copied into
`~/.config`. This keeps applications isolated from the Git checkout, but edits
made directly under `~/.config` do not automatically return to the repository.
On each rerun, managed configuration is backed up and replaced rather than
merged, while the ignored Hyprland `machine.lua` is retained. See the project
discussion before switching to a symlink deployment model.

## Power and battery

The baseline is `power-profiles-daemon`, enabled by the installer. It exposes
the `power-saver`, `balanced`, and `performance` profiles, and the installer
turns on its battery-aware switching so the profile follows the AC state by
itself where the installed version supports it.

Waybar shows the battery level and the active power profile. The profile can
also be driven from the shell:

```bash
powerprofilesctl get
powerprofilesctl list
powerprofilesctl set power-saver
```

TLP is deliberately **not** installed. TLP and power-profiles-daemon change the
same kernel tunables and overwrite each other, and TLP's own documentation
recommends running only one of them. The installer's verification step fails if
it finds `tlp.service` enabled alongside the daemon. TLP remains the right
choice later if more granular idle, PCIe, USB, or radio tuning turns out to be
needed — but it should replace power-profiles-daemon rather than join it.

`thermald` is installed and enabled only when an Intel CPU is detected, since
it implements Intel-specific thermal interfaces.

### Display refresh rate

The 3200x2000 panel is the largest single power draw on this machine, so
`~/.config/hypr/scripts/power-watch.sh` runs in the Hyprland session and drops
the internal panel to 60 Hz on battery, restoring its highest available refresh
rate on AC. It writes nothing to disk: the change is applied with `hyprctl
eval` and `hl.monitor(...)`, so `hyprctl reload` returns to the mode in
`machine.lua`. The watcher chooses the advertised panel mode closest to 60 Hz
rather than assuming it is named exactly `60`, and retries temporary failures.
A machine with no external power supply is treated as a desktop and the
watcher exits immediately.

### NVIDIA runtime power management

The dGPU is left at the driver default on purpose.
`NVreg_DynamicPowerManagement` defaults to `0x03`, which NVIDIA documents as
fine-grained runtime D3 on Ampere-and-newer notebooks, and the driver already
ships an Arch runtime-PM rule as `/usr/lib/udev/rules.d/60-nvidia.rules`.
Forcing `0x02` would add risk
without adding capability, so the installer reports the live state instead:

```bash
cat /proc/driver/nvidia/gpus/*/power
```

The first-install baseline uses NVIDIA's default kernel-callback suspend
mechanism. It needs no special systemd units and preserves the essential video
memory needed by ordinary workloads. The installer deliberately does not
enable `nvidia-suspend`, `nvidia-hibernate`, or `nvidia-resume`.

Full video-memory preservation is a separate opt-in configuration. It requires
the `/proc/driver/nvidia/suspend` systemd units,
`NVreg_PreserveVideoMemoryAllocations=1`, and disk-backed temporary storage
large enough for the GPU's allocations. That should be configured only if CUDA
or another workload proves that it needs it, and only after ordinary suspend
and resume have been validated on the laptop.

### What still needs measuring on real hardware

None of this has been validated on the physical laptop yet. After the first
install, check:

1. Idle power draw on battery, with and without the dGPU awake.
2. That the dGPU actually reaches `Runtime D3 status: Enabled`.
3. Suspend and resume, including with an external display attached.
4. Whether 60 Hz on battery is a worthwhile trade against the perceived
   smoothness loss.

Power tuning beyond this baseline should follow those measurements rather than
being applied blindly.

- Power profiles: https://man.archlinux.org/man/powerprofilesctl.1
- TLP and power-profiles-daemon conflict: https://linrunner.de/tlp/faq/ppd.html
- NVIDIA runtime D3: https://download.nvidia.com/XFree86/Linux-x86_64/580.95.05/README/dynamicpowermanagement.html

## Hardware-specific setup

Windows hardware inspection has confirmed:

- Lenovo model `83FD`
- internal CSO1626 panel at `3200x2000@165`
- Windows-recommended display scale of 200%
- internal panel currently connected to Intel UHD Graphics (`8086:a788`)
- NVIDIA GeForce RTX 4070 Laptop GPU (`10de:2860`) at PCI `01:00.0`

The installer discovers the Linux-specific details on the physical machine. It:

- identifies display-class PCI devices through sysfs
- installs Intel graphics support and the appropriate Arch `nvidia-open`
  variant for the detected kernel
- installs `nvidia-prime` for explicit application offload
- creates stable `/dev/dri/hyprland-igpu` and
  `/dev/dri/hyprland-nvidia` aliases with a generated udev rule
- generates an ignored `gpu/local.lua` with the iGPU first in
  `AQ_DRM_DEVICES`
- detects the connected eDP/LVDS/DSI panel and generates the ignored
  `machine.lua`
- refines `preferred` to the panel's highest-resolution, highest-refresh mode
  after Hyprland first starts

The generated local files carry a marker. Rerunning the installer can refresh
generated values, but a hand-edited local file is preserved. External displays
continue to receive a portable preferred-mode fallback.

`~/.config/hypr/machine.example.lua` documents the Windows-verified
`3200x2000@165` configuration and scale `2`. It is a reference and no longer
needs to be copied manually. Scale `1.6` remains a valid manual preference for
more logical workspace.

Reboot after the first installation so the NVIDIA module and udev aliases are
available before Hyprland starts. CUDA tooling remains separate, because CUDA
frameworks have workload-specific requirements. Power management is covered
above; anything beyond that conservative baseline should follow real suspend,
external-display, and runtime-PM measurements rather than being applied
blindly.
