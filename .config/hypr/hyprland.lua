-- ~/.config/hypr/hyprland.lua
-- Docs: https://wiki.hypr.land/Configuring/Start/

---- MY PROGRAMS ----

mainMod    = "SUPER"
terminal   = "kitty"
menu       = "rofi -show combi -modi combi"
fileManager = "thunar"
browser    = "zen-browser"


---- AUTOSTART ----

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("dunst")
    hl.exec_cmd("~/.config/hypr/scripts/notification-dismiss-watch.sh")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("sh -c 'command -v hypridle >/dev/null && { pgrep -x hypridle >/dev/null || exec hypridle; }'")
    hl.exec_cmd("sh -c 'sleep 1; ~/.config/hypr/scripts/workspace-overview.sh --load'")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")

    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("qs -d -c volume-osd")
    hl.exec_cmd("sh -c 'sleep 1; ~/.config/themes/restore.sh'")
    hl.exec_cmd("sh -c 'sleep 2; ~/.config/hypr/scripts/detect-display.sh'")
    hl.exec_cmd("sh -c 'sleep 3; ~/.config/hypr/scripts/power-watch.sh'")
end)

---- ENVIRONMENT VARIABLES ----

require("gpu")

-- The session environment lives in ~/.config/environment.d, not in any
-- shell's rc file. SDDM builds the starting environment by running the login
-- shell, so without this step PATH depends on which shell is chosen. The
-- systemd generator parses the files exactly as systemd does. PATH-style
-- values are de-duplicated so `hyprctl reload` never grows them.
local function dedupe_path(value)
    local seen, parts = {}, {}
    for entry in value:gmatch("[^:]+") do
        if not seen[entry] then
            seen[entry] = true
            parts[#parts + 1] = entry
        end
    end
    return table.concat(parts, ":")
end

local generator = io.popen("/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator 2>/dev/null")
if generator then
    for line in generator:lines() do
        local key, value = line:match("^([%w_]+)=(.*)$")
        if key then
            if key:match("PATH$") then value = dedupe_path(value) end
            hl.env(key, value)
        end
    end
    generator:close()
end

hl.env("XCURSOR_SIZE", "14")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")

---- INPUT ----

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0.5,
        touchpad = {
            natural_scroll = false,
            tap_to_click = true,
        },
    },
})

---- LOOK AND FEEL ----

hl.config({ render = { expand_undersized_textures = false}})
hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 3,
        border_size = 2,
        resize_on_border = true,
        extend_border_grab_area = 14,
        hover_icon_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
        snap = {
            enabled = true,
            window_gap = 8,
            monitor_gap = 8,
            border_overlap = false,
            respect_gaps = true,
        },
    },
    decoration = {
        rounding = 8,
        blur = {
            enabled = true,
            size = 5,
            passes = 1,
            vibrancy = 0.2,
        },
        shadow = {
            enabled = true,
            range = 8,
            render_power = 3,
        },
    },
    animations = {
        enabled = true,
    },
})

hl.curve("easeOut", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.0} } })

hl.animation({ leaf = "windows",    enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "border",     enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 7, bezier = "default", style = "slidefade" })

-- LAYOUT
hl.config({
    dwindle = {
        preserve_split = true,
        smart_resizing = true,
        precise_mouse_move = true,
    },
})
hl.config({
    master = { new_status = "master" },
})

-- MISC
hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

---- SPLIT-OUT FILES ----

require("keybinds")
require("monitors")
require("rules")

-- HyprMod owns this machine-local file. Load it last so changes made in the
-- GUI are explicit overrides without rewriting the Git-managed modules.
pcall(require, "hyprland-gui")
