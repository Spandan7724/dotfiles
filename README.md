# Personal Arch + Hyprland dotfiles

Personal tiled Hyprland desktop configuration for a fresh Arch Linux
installation. Normal application windows use the dwindle layout, while utility
windows and file dialogs float where appropriate.

The desktop stack uses Waybar, Rofi, Quickshell, Hyprlock, Wlogout, Dunst,
Kitty, Thunar, PipeWire, Fish or Zsh, Starship, and Matugen for
wallpaper-derived colors.

## Applications

- Default browser: Zen Browser
- Other browsers: Brave, Google Chrome
- Terminal: Kitty
- File manager: Thunar
- Graphical editor: Zed
- Terminal editors: Helix and Neovim with NvChad
- Emacs: Doom Emacs
- Login screen: SDDM with the SilentSDDM theme (nord variant)
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
is the expected path; reboot afterwards and log in from SDDM with the
"Hyprland (uwsm-managed)" session.

What it does, in order: updates the system, detects graphics and CPU hardware,
finds or bootstraps an AUR helper, resolves and installs official and AUR
packages, backs up any managed configuration it is about to replace, installs
the dotfiles, configures graphics, installs the wallpapers, enables
NetworkManager, Bluetooth, PipeWire, firewalld, and CUPS, configures the SDDM
login screen and zram, configures power management, sets Zen as the default
browser and applies the initial theme (Wallpaper Dark), installs
reboot-to-Windows on dual-boot machines, sets up the Rust toolchain, installs
Doom Emacs, then verifies the result and prints a summary. HyprMod provides a graphical editor for Hyprland settings and
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

The repository ships the NvChad configuration in `.config/nvim`; the official
`NvChad/starter` is only cloned when that directory is missing. After
installation:

1. Start `nvim` and wait for plugins to finish installing.
2. Run `:MasonInstallAll`.
3. Run `:TSInstallAll`.

## Doom Emacs

The personal Doom configuration lives in `.config/doom`. The installer clones
Doom itself into `~/.config/emacs` and runs `doom install --no-config`, which
builds the packages without touching that configuration. After changing
`init.el` or `packages.el`, run `doom sync`.

## Reboot to Windows

On a machine that also has Windows Boot Manager, Power → Windows in the desktop
menu, the "Reboot to Windows" launcher entry, or `reboot-windows` in a shell
sets UEFI `BootNext` to Windows Boot Manager and reboots. The firmware then
starts Windows directly, without GRUB, which keeps BitLocker's measured boot
path intact. `BootNext` only lasts one boot, so the following reboot returns
to Arch. The privileged half is `system/dotfiles-reboot-windows-root`, allowed
through a sudoers rule limited to its `set` and `clear` arguments.

## Coordinated themes

`Super + Shift + T` opens the theme selector. A fresh install starts on
`wallpaper-dark` with `wallpaper-19.jpg`. Other profiles include:

- `monochrome-dark`
- `monochrome-light`

Switching profiles coordinates Kitty, Waybar, Rofi, Dunst, Hyprlock, Wlogout,
GTK 3/4, Starship, the system light/dark preference, the Papirus icon variant,
and the wallpaper. GTK uses its supported theme and
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
| Starship | symlink into `themes/current` | not recolored |

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

Starship and GTK continue to follow the coordinated named light/dark profile.
Their appearance remains stable while the desktop chrome and terminal palette
follow the wallpaper.
Already-running GTK applications may need to be restarted.

The theme implementation follows each application's native format:

- Kitty configuration fragments and reload signals: https://sw.kovidgoyal.net/kitty/conf/
- Waybar GTK CSS styling: https://github.com/Alexays/Waybar/blob/master/man/waybar.5.scd.in
- Rofi Rasi themes: https://davatorium.github.io/rofi/current/rofi-theme.5/
- GTK settings and system color preference: https://docs.gtk.org/gtk4/class.Settings.html
- Starship TOML schema and palettes: https://starship.rs/config/
- Matugen configuration and templates: https://github.com/InioX/matugen
- Quickshell watched files: https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/FileView/
- Dunst settings and drop-in directory: https://man.archlinux.org/man/dunst.5
- Hyprlock configuration: https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/

## Keybindings

| Keybinding | Action |
| --- | --- |
| `Super + T` | Open the default terminal |
| `Super + D` | Open the dedicated applications menu |
| `Super + E` | Open the default file manager |
| `Super + B` | Open the default browser |
| `Super + R` | Search files |
| `Super + Shift + D` | Search the web |
| `Super + =` | Calculate and copy the result |
| `Super + ;` | Choose and copy an emoji or symbol |
| `Super + X` | Open quick settings |
| `Super + F1` | Show the searchable shortcut guide |
| `Super + A` | Open audio settings |
| `Super + Q` | Close active window |
| `Super + Shift + Q` | Force-kill active window |
| `Super + F` | Toggle fullscreen |
| `Super + M` | Toggle maximize |
| `Super + Space` | Toggle floating and tiled state |
| `Super + Shift + Space` | Toggle every window on the workspace between floating and tiled |
| `Super + C` | Center a floating window |
| `Super + P` | Toggle pseudotile |
| `Super + Shift + P` | Pin a floating window |
| `Super + O` | Cycle active-window opacity |
| `Super + \` | Toggle dwindle split direction |
| `Super + Arrow` | Focus in a direction |
| `Super + Shift + Arrow` | Move in a direction |
| `Super + Alt + Arrow` | Swap tiled windows |
| `Super + Ctrl + Arrow` | Resize a window |
| `Super + Ctrl + Alt + Arrow` | Move a floating window by 40 pixels |
| `Super + Shift + -/+` | Adjust the current split ratio |
| `Super + Shift + \` | Swap the two halves of the current split |
| `Super + Ctrl + H/J/K/L` | Preselect the next split direction |
| `Super + Alt + H/L/K/J` | Place a floating window on the left/right/top/bottom half |
| `Super + Alt + U/I/N/,` | Place a floating window in a screen corner |
| `Super + left mouse drag` | Move or rearrange a window |
| `Super + right mouse drag` | Resize a window or tiled split |
| `Super + Shift + right mouse drag` | Resize a floating window while preserving its aspect ratio |
| `Alt + Tab` | Cycle windows |
| `Super + Tab` | Open the workspace and window overview |
| `Super + G` | Toggle a tabbed window group |
| `Super + Ctrl + G` | Toggle performance mode |
| `Super + [` / `Super + ]` | Cycle grouped windows |
| `Super + 1..0` | Switch to workspace 1–10 |
| `Super + Shift + 1..0` | Move a window and follow it |
| `Super + Ctrl + 1..0` | Move a window without leaving the current workspace |
| `Super + Page Up/Down` | Switch to the previous/next occupied workspace |
| `Super + S` | Toggle the scratchpad |
| `Super + Shift + S` | Send a window to the scratchpad |
| `Super + Return` | Open a dropdown terminal |
| `Super + ,/.` | Focus the previous/next monitor |
| `Super + Shift + ,/.` | Move a window to the previous/next monitor |
| `Super + Ctrl + ,/.` | Move a workspace to the previous/next monitor |
| `Super + W` | Open wallpaper selector |
| `Super + Alt + W` | Choose a random wallpaper |
| `Super + Alt + Page Up/Down` | Use the previous/next wallpaper |
| `Super + Shift + T` | Open coordinated theme selector |
| `Super + /` | Search live Hyprland keybindings |
| `Super + Shift + /` | Open or focus HyprMod advanced settings |
| `Super + Escape` / `Super + Alt + Space` / `Super + F2` | Open the unified desktop control menu |
| `Super + Shift + W` | Toggle Waybar |
| `Super + V` | Search clipboard history and paste the selected text or image |
| `Super + Ctrl + T` | Transcode a picture or video |
| `Super + Ctrl + P` | Open the package-manager TUI |
| `Super + Ctrl + D` | Choose default applications |
| `Super + Ctrl + E` | Open the default code editor |
| `Super + Shift + V` | Open the virtual-machine menu |
| `Super + L` | Lock with Hyprlock |
| `Super + Grave` | Open the lock, sleep, hibernate, logout, restart, and shutdown menu |
| `Super + Shift + E` | Exit Hyprland |
| `Super + mouse wheel` | Switch occupied workspaces |
| `Super + Ctrl + mouse wheel` | Zoom the compositor view |
| `Print` / `Shift + Print` | Capture the full screen / a selected region |
| `Alt + Print` / `Ctrl + Print` | Capture the active window / copy a selected region |
| `Super + Print` | Capture and annotate a selected region |
| `Super + Ctrl + Print` | OCR a selected region to the clipboard |
| `Super + Alt + Print` | Capture the full screen after five seconds |
| `Super + Shift + R` | Start or stop a selected-region screen recording |
| `Super + Shift + C` | Pick and copy a color |
| `Super + Shift + N` | Show the last notification from history |
| `Super + Ctrl + N` | Toggle do not disturb |
| `Super + Ctrl + W/B` | Open network / Bluetooth settings |
| `Super + Ctrl + R` | Reload Hyprland and Waybar |
| `XF86MonBrightnessUp/Down` | Adjust brightness |
| `XF86AudioRaise/LowerVolume` | Adjust volume |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioMicMute` | Toggle microphone mute |
| `XF86AudioPlay/Pause/Next/Previous` | Control media |

`Super + Tab` opens a native 5×2 overview of workspaces 1–10 with live window
previews. Navigate with the arrow keys or `H/J/K/L`, select with Enter or Space,
cancel with Escape, click a workspace, or drag a window preview to another
workspace. The overview is provided by HyprExpo and is built against the exact
installed Hyprland revision by the installer.

The bar keeps navigation, search, time, audio, battery, and current state visible.
Its workspace module shows occupied workspaces and the active workspace instead
of reserving room for all ten. The Arch button opens the desktop control menu;
the Search pill opens the dedicated applications launcher.

The desktop menu follows a compact hierarchy. **Capture** holds screenshots
(region, window, full screen, delayed, annotate, to clipboard), screen
recording, OCR, and the colour picker; **Style** holds the theme, wallpapers,
opacity, the bar, and reload; **Setup** doubles as quick settings and holds
defaults, Wi-Fi, Bluetooth, audio, brightness, night light, displays, the power
profile, packages, virtual machines, fingerprint, and advanced Hyprland
settings; **Tools** holds clipboard, calculator, emoji, file and web search,
transcoding, and monitoring. **Setup › Screen and lock** sets the idle
timeouts — when the session locks, when the screen blanks, when the machine
suspends — plus an immediate lock and a keep-awake hold. Right-clicking the Waybar settings icon opens the
Defaults menu directly.

Labels are one or two words. Everything else a person might type — `wallpaper`,
`ocr`, `qemu`, `poweroff` — lives in a keywords column that is searched but
never shown.

The root lists the categories and also indexes every action in the tree, so a
search resolves to the thing itself rather than to the category containing it:
typing `theme` gives **Theme**, with a dim **Style** under it saying where it
lives. An indexed row leads with its own name and carries its path as a second
line, the way the Omarchy menu does it, rather than spelling out
`Style › Theme` inline. Category rows have nothing to put on that second line
and stay one line, centred. Category rows carry no
keywords, which is what makes that work — a category matching `ocr` would
otherwise rank alongside the leaf that actually does it. For the same reason
categories carry no descriptive subtitle: the words in one would match, and
`theme` would surface **Style** all over again. Matching is
substring-per-token rather than fuzzy: fuzzy matched scattered letters across
the hidden keyword column, so `idle` buried the one row that says idle under
every row containing an i, d, l and e. Submenus are marked with a `›` in a
column of their own; Escape steps back one level rather than closing the menu,
and pressing the menu key again closes it outright.

Rows whose program is not installed, or whose hardware is absent, are hidden
rather than listed and broken. Hibernate, for instance, only appears when a
non-zram swap device and suspend-to-disk are both available.

The whole menu is one declarative table at the top of
`.config/hypr/scripts/desktop-menu.sh` — `parent | id | icon | label | keywords
| action | when` — rendered by a single generic pass. Adding an entry is one
line. Selection is dispatched on the hidden `id` column rather than on the
visible label, so rewording a row cannot break its action. `power-menu.sh` and
`control-center.sh` are thin wrappers onto the `power` and `setup` routes, so
the standalone bindings and the menu can never drift apart.

The Defaults menu configures the terminal, login shell, browser, editor, file
manager, PDF viewer, image viewer, and video player. It updates both the
dotfiles launch wrappers and the relevant XDG MIME handlers.
Less frequent information expands in hover drawers: tray applications;
Bluetooth; microphone state; brightness and system resources; updates, night
light, and idle inhibition; and the power action. Click the network, audio,
battery, notification, or settings items for their normal controls. Right-click
the centered search pill to open the workspace overview.

## Graphical shortcut management

`Super + /` opens a fast searchable guide generated from the bindings that
Hyprland actually loaded. `Super + Shift + /` opens or focuses HyprMod when a
graphical editor is needed. Its Keybindings page can inspect, capture, add,
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

On the Lenovo Legion 7, clicking Waybar's power-profile icon opens a profile
menu that coordinates the CPU/platform profile and NVIDIA ceiling. Power saver
uses a strict 55 W cap, balanced starts near 80 W, and performance enables
Dynamic Boost up to the Lenovo-rated 130 W TGP. The helper caps every request
to the min/max range reported by the NVIDIA driver. It pauses `nvidia-powerd`
for the strict power-saver cap and runs it for balanced and performance. The installer
places the validated helper under `/usr/local/libexec`; the user-writable
configuration never runs arbitrary commands as root.

## Themes and wallpapers

The built-in profiles are Monochrome Dark, Monochrome Light, Gruvbox Dark,
Everforest, Tokyo Night, Wallpaper Dark, and Wallpaper Light. A named profile
coordinates Rofi, Waybar, Kitty, Dunst, Hyprlock, Wlogout, GTK mode, icons, and
Starship. Wallpaper selection remains independent. The two Wallpaper profiles
use Matugen colors from whichever wallpaper is selected; every other profile
keeps its own palette while allowing any wallpaper.

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
