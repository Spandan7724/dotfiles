# Personal Arch + Hyprland dotfiles

Personal tiled Hyprland desktop configuration for a fresh Arch Linux
installation. Normal application windows use the dwindle layout, while utility
windows and file dialogs float where appropriate.

The desktop stack uses Waybar, Quickshell, Hyprlock, Dunst,
Kitty, Thunar, PipeWire, Fish or Zsh, Starship, and Matugen for
wallpaper-derived colors.

## Applications

- Default browser: Zen Browser
- Other browsers: Brave, Google Chrome
- Launcher: Vicinae (Alt+Space), with the desktop menu's tools as script commands
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

## Virtual machines

`Super + Shift + V` (or Setup → Virtual machines in the desktop menu) opens a
themed virtual machine manager built with Quickshell
(`.config/quickshell/vm-manager`). It lists every libvirt VM on
`qemu:///system` with its state and resources, and offers Console, Shut down,
Reboot, Force stop, Start, Settings (virt-manager's editor) and Delete.

**New VM** creates a machine in two ways:

- **Download an OS**: pick from quickget's catalogue of about 90 systems and
  700 releases (Ubuntu, Fedora, Arch, Debian, Windows 10/11, the BSDs, and so
  on). The installer ISO is downloaded, with a progress bar, and the VM boots
  straight into it. Windows comes directly from Microsoft.
- **Use an ISO**: pick an ISO from `~/Downloads`, one downloaded earlier, or
  type a path.

Sensible defaults are filled in and can be adjusted: 2 vCPU, 4 GB and 30 GB
for Linux, and 4 vCPU, 8 GB and 80 GB for Windows. Linux VMs use UEFI with
Secure Boot off (many live ISOs are unsigned); Windows gets UEFI, Secure Boot
and an emulated TPM 2.0, as Windows 11 requires. Legacy BIOS is available for
old systems.

**Display** offers 3D acceleration (the default for everything except Windows):
a virtio GPU with virgl, rendered through SPICE's local OpenGL path on the host
GPU. Wayland desktops such as Hyprland (and so Omarchy), GNOME and KDE need it
to run smoothly. On a hybrid laptop the integrated GPU renders it, because
virgl works poorly with NVIDIA's proprietary driver. Windows has no virgl
driver and always gets the basic display. Consoles open with
`virt-viewer --attach`, which is the only way into a 3D VM because its SPICE
display has no network listener.

A 3D VM is also given the host monitor's physical resolution (3200×2000 on this
laptop) as its preferred display mode, and its console opens with
`--auto-resize=never`. On a HiDPI host, auto-resize would ask the guest for the
window's logical size (half the real pixels at 2× scaling) and stretch the
result, which looks blurry. Rendering at full resolution lets the guest apply
its own 2× scaling, so it looks like the host screen. Press F11 in the console
for full screen.

ISOs are uploaded into a libvirt storage pool named `vm-isos`
(`/var/lib/libvirt/isos`) rather than read from the home directory, which QEMU
cannot access. This needs no sudo, only membership of the `libvirt` group,
which the installer sets up. An ISO is reused by later VMs of the same
release, and deleting a VM removes its disks but keeps the ISO. Downloads run
in the background, so the window can be closed meanwhile.

Everything is ordinary libvirt, so `virt-manager` and `virsh` see the same
machines. The backend is `vmctl.sh`, which can also be used directly, for
example `vmctl.sh list`.

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

- `gruvbox-dark`, `everforest`, `tokyo-night`
- `monochrome-dark`, `monochrome-light`
- `solitude`, `vantablack` (palettes from Omarchy)
- `wallpaper-light`

Switching profiles coordinates Kitty, Waybar, Rofi, Dunst, Hyprlock, Wlogout,
GTK 3/4, Starship, the system light/dark preference, the Papirus icon variant,
and the wallpaper. Named profiles also theme Thunar, the Quickshell panels,
Hyprland window borders, Neovim (NvChad), Doom Emacs, Helix, and btop; the
wallpaper profiles leave those on their defaults. GTK uses its supported theme and
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
| Thunar | `gtk-3.0/gtk.css` imports `thunar.css` | `thunar-colors.css` |
| Quickshell | `quickshell.json` copied over `theme.json` | `theme.json` |
| Hyprland borders | `hyprland.lua` loaded by `hypr/hyprland.lua` | not recolored |
| Neovim (NvChad) | `nvim.lua` names a base46 theme, `base46.lua` for custom ones | not recolored |
| Doom Emacs | `doom.el` sets `doom-theme`, `doom-palette.el` for custom ones | not recolored |
| Helix, btop | `helix.toml`, `btop.theme` linked as the `dotfiles` theme | not recolored |
| Vicinae | `vicinae.toml` installed as its `dotfiles` theme | `vicinae.toml` from the wallpaper palette |

The newer app files come from each profile's `colors.toml` (Omarchy's palette
format). Its `[apps]` table names a matching built-in theme, such as NvChad's
`gruvbox` or Doom's `doom-tokyo-night`; apps without one get a theme generated
from the palette. After editing a palette, regenerate and re-apply:

```bash
~/.config/themes/generate.py everforest          # app files only
~/.config/themes/generate.py my-theme --all      # a new theme: every file
~/.config/themes/apply.sh everforest
```

The switcher reloads Hyprland, Helix, every running Neovim, and a running Emacs
server. Thunar and btop pick the theme up the next time they open.

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
| `Super + Shift + N` | Open notes: a new Markdown note in `~/notes` in Doom Emacs, or the notes app chosen under Defaults |
| `Super + B` | Open the default browser |
| `Super + Shift + Return` | Open Doom Emacs (starts the Emacs daemon if needed) |
| `Super + R` | Search files |
| `Super + Shift + D` | Search the web |
| `Super + =` | Calculate and copy the result |
| `Super + ;` | Choose and copy an emoji or symbol |
| `Super + Alt + X` | Open quick settings |
| `Super + F1` / `Super + /` | Show the keyboard shortcut cheatsheet |
| `Super + A` | Open audio settings |
| `Super + Shift + A` | Pick a folder (Enter alone = home) and start the default coding agent there; choose Claude Code, Codex, OpenCode, or Amp under Defaults |
| `Super + Q` | Close active window |
| `Super + Shift + Q` | Force-kill active window |
| `Super + F` | Toggle fullscreen |
| `Super + M` | Toggle maximize |
| `Super + Space` | Toggle floating and tiled state |
| `Super + Shift + Space` | Toggle every window on the workspace between floating and tiled |
| `Super + Alt + C` | Center a floating window |
| `Super + P` | Toggle pseudotile |
| `Super + Shift + P` | Pin a floating window |
| `Super + O` | Pop a window out (float, center, and pin); press again to tile it |
| `Super + Shift + O` | Cycle active-window opacity |
| `Super + J` / `Super + \` | Toggle the split direction |
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
| `Super + C` / `Super + V` / `Super + X` | Universal copy / paste / cut (works in terminals too) |
| `Super + Ctrl + V` | Search clipboard history and paste the selected text or image |
| `Super + Ctrl + T` | Transcode a picture or video |
| `Super + Ctrl + P` | Open the package-manager TUI |
| `Super + Ctrl + D` | Choose default applications |
| `Super + Ctrl + E` | Open the default code editor |
| `Super + Shift + V` | Open or close the virtual machine manager |
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
| `Super + Ctrl + Alt + N` | Show the last notification from history |
| `Super + Ctrl + N` | Toggle do not disturb |
| `Super + Ctrl + W/B` | Open the Wi-Fi / Bluetooth panel |
| `Super + Ctrl + S` | Open the display panel (brightness, scale, text size) |
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

All menus are drawn by Quickshell, in the same long-running `panels` daemon as
the Wi-Fi, Bluetooth, Display, and media pop-ups, so they share one look, follow
the desktop theme, and open instantly. Rofi is no longer used.

**Desktop menu** (`Super + Escape`, the Arch button). **Capture** holds
screenshots, screen recording, text capture (OCR), and the colour picker;
**Style** holds the theme, wallpapers, opacity, the bar, and reload; **Setup**
doubles as quick settings and holds Wi-Fi, Bluetooth, audio, display, monitor
layout, night light, screen and lock, the power profile, default apps,
packages, virtual machines, fingerprint, and advanced Hyprland settings;
**Tools** holds clipboard, calculator, emoji, coding agent, notes, file and web
search, transcoding, and the system monitor. Every row has a one-line
description, and toggles such as the menu bar, night light, and screen
recording show whether they are on.

Searching from the top level looks through every submenu and every installed
app, and shows where each result lives. Matching is per word: label matches
rank above keyword and description matches, and a match at the start of a word
ranks above one inside it. Arrow keys or Ctrl+J/K move, Enter or → opens,
← or Backspace goes back, Escape clears the search, then steps back, then
closes, and pressing the menu key again closes it outright.

The menu is defined in `.config/quickshell/panels/menu.json`. Ids are dotted
paths (`setup.audio` sits under Setup) and an entry without an `action` is a
submenu. `when` hides a row whose shell test fails (so missing programs are
never listed), and `state` shows On/Off from a shell test; both are answered by
one batched shell process each time the menu opens. The file is watched, so
edits apply without a restart.

**App launcher** (`Super + D`, the Search pill) lists installed applications
with their icons, most-used first.

**Session screen** (`Super + Grave`, the bar's power button) is a full-screen
grid: Lock, Suspend, Hibernate, Log out, Restart, Windows, Firmware, and Shut
down, each with a letter shortcut. Actions that end the session need a second
press. It shows uptime and battery and warns when a package manager or a
download is still running. Its logic lives in `hypr/scripts/session.sh`.

**Pickers.** `hypr/scripts/menu-select` is a drop-in for `rofi -dmenu`: it
reads choices on stdin and prints the chosen line, so the defaults, theme,
coding agent, clipboard, emoji, file search, calculator, and other pickers are
ordinary shell scripts. It supports tab-separated hidden columns
(`-display-columns`), an icon column, custom text, and plain text prompts.

The Defaults menu configures the terminal, login shell, browser, editor, file
manager, PDF viewer, image viewer, and video player. It updates both the
dotfiles launch wrappers and the relevant XDG MIME handlers.
Less frequent information expands in hover drawers: tray applications;
Bluetooth; microphone state; brightness and system resources; updates, night
light, and idle inhibition; and the power action. Click the network, audio,
battery, notification, or settings items for their normal controls. Right-click
the centered search pill to open the workspace overview.

## Graphical shortcut management

`Super + F1` or `Super + /` opens a cheatsheet generated from the bindings
Hyprland actually loaded, grouped into categories in masonry columns, with
number and direction families collapsed into one row (`Super + 1 – 0`,
`Super + ← ↓ ↑ →`). Typing filters it. Categories come from `section()` calls in
`.config/hypr/keybinds.lua`, which store the category as a prefix on each
bind's description. `Super + Shift + /` opens or focuses HyprMod when a
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
