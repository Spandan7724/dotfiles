-- ~/.config/hypr/keybinds.lua
-- Hyprland 0.56 Lua dispatcher API:
-- https://wiki.hypr.land/Configuring/Basics/Dispatchers/

local home = os.getenv("HOME")
local scripts = home .. "/.config/hypr/scripts"

-- The keyboard cheatsheet (Super+F1) groups shortcuts by category. section()
-- sets the category for the binds that follow; it is stored as a
-- "Category: " prefix on each description, which the cheatsheet splits off.
local category = nil
local function section(name)
    category = name
end

local function bind(keys, dispatcher, description, options)
    options = options or {}
    options.description = category and (category .. ": " .. description) or description
    hl.bind(keys, dispatcher, options)
end

local function launch(command)
    return hl.dsp.exec_cmd(command)
end

-- Launchers and desktop panels
section("Apps")
bind(mainMod .. " + T", launch(scripts .. "/default-launcher.sh terminal"), "Open default terminal")
bind(mainMod .. " + D", launch(scripts .. "/apps-menu.sh"), "Open applications menu")
bind("ALT + Space", launch("vicinae toggle"), "Open launcher (apps, files, calculator, clipboard)")
bind(mainMod .. " + E", launch(scripts .. "/default-launcher.sh file-manager"), "Open default file manager")
bind(mainMod .. " + SHIFT + N", launch(scripts .. "/default-launcher.sh notes"), "Open notes (default notes app)")
bind(mainMod .. " + B", launch(scripts .. "/default-launcher.sh browser"), "Open default browser")
bind(mainMod .. " + SHIFT + Return", launch('emacsclient -c -a ""'), "Open Doom Emacs")
section("Desktop")
bind(mainMod .. " + ALT + X", launch(scripts .. "/control-center.sh"), "Open quick settings")
bind(mainMod .. " + F1", launch(scripts .. "/keybinds.sh"), "Show keyboard shortcuts")
bind(mainMod .. " + F2", launch(scripts .. "/desktop-menu.sh"), "Open desktop control menu")
bind(mainMod .. " + ALT + Space", launch(scripts .. "/desktop-menu.sh"), "Open desktop control menu")
bind(mainMod .. " + Escape", launch(scripts .. "/desktop-menu.sh"), "Open desktop control menu")
bind(mainMod .. " + slash", launch(scripts .. "/keybinds.sh"), "Search keyboard shortcuts")
bind(mainMod .. " + SHIFT + slash", launch(scripts .. "/hyprmod-launch.sh"), "Open advanced Hyprland settings")
section("Apps")
bind(mainMod .. " + A", launch("pavucontrol"), "Open audio settings")
bind(mainMod .. " + SHIFT + A", launch(scripts .. "/agent-launcher.sh"), "Start coding agent in a chosen folder")
bind(mainMod .. " + CTRL + A", launch(scripts .. "/agent-launcher.sh --choose"), "Choose a coding agent, then a folder")
bind(mainMod .. " + SHIFT + B", launch(terminal .. " --class dotfiles-btop -e btop"), "Open system monitor")
section("Tools")
bind(mainMod .. " + R", launch(scripts .. "/file-search.sh"), "Search files")
bind(mainMod .. " + SHIFT + D", launch(scripts .. "/web-search.sh"), "Search the web")
bind(mainMod .. " + equal", launch(scripts .. "/calculator.sh"), "Open calculator")
bind(mainMod .. " + semicolon", launch(scripts .. "/emoji.sh"), "Choose emoji or symbol")
section("Desktop")
bind(mainMod .. " + CTRL + W", launch(scripts .. "/panel.sh wifi"), "Open Wi-Fi panel")
bind(mainMod .. " + CTRL + B", launch(scripts .. "/panel.sh bluetooth"), "Open Bluetooth panel")
bind(mainMod .. " + CTRL + S", launch(scripts .. "/panel.sh display"), "Open display scale and text size panel")

-- Session and window state
section("Windows")
bind(mainMod .. " + Q", hl.dsp.window.close(), "Close active window")
bind(mainMod .. " + SHIFT + Q", hl.dsp.window.kill(), "Force-kill active window")
section("Session")
bind(mainMod .. " + L", launch("hyprlock"), "Lock session")
section("Session")
bind(mainMod .. " + GRAVE", launch(scripts .. "/power-menu.sh"), "Open power and session menu")
section("Session")
bind(mainMod .. " + SHIFT + E", hl.dsp.exit(), "Exit Hyprland")
section("Windows")
bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), "Toggle fullscreen")
bind(mainMod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), "Toggle maximize")
bind(mainMod .. " + Space", hl.dsp.window.float({ action = "toggle" }), "Toggle floating")
bind(mainMod .. " + ALT + C", hl.dsp.window.center(), "Center floating window")
bind(mainMod .. " + P", hl.dsp.window.pseudo({ action = "toggle" }), "Toggle pseudotile")
bind(mainMod .. " + SHIFT + P", hl.dsp.window.pin({ action = "toggle" }), "Pin floating window")
section("Layout")
bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), "Toggle window split direction")
bind(mainMod .. " + backslash", hl.dsp.layout("togglesplit"), "Toggle dwindle split direction")
bind(mainMod .. " + SHIFT + backslash", hl.dsp.layout("swapsplit"), "Swap the two halves of the current split")
bind(mainMod .. " + SHIFT + minus", hl.dsp.layout("splitratio -0.05"), "Shrink current split", { repeating = true })
bind(mainMod .. " + SHIFT + equal", hl.dsp.layout("splitratio +0.05"), "Grow current split", { repeating = true })
local default_opacity = 0.9 -- keep in sync with the opacity rule in rules.lua
local opacity_opaque = {}

section("Windows")
bind(mainMod .. " + O", launch(scripts .. "/window-pop.sh"), "Pop window out (float and pin)")
bind(mainMod .. " + SHIFT + O", function()
    local window = hl.get_active_window()
    if window == nil then
        return
    end

    local opaque = not opacity_opaque[window.address]
    opacity_opaque[window.address] = opaque or nil
    -- set_prop "opacity" only covers the focused state; opacity_inactive is a
    -- separate prop, so set both or the window reverts to the rule when unfocused.
    local alpha = tostring(opaque and 1.0 or default_opacity)
    hl.dispatch(hl.dsp.window.set_prop({ prop = "opacity", value = alpha .. " override" }))
    hl.dispatch(hl.dsp.window.set_prop({ prop = "opacity_inactive", value = alpha }))
end, "Toggle active-window opacity between opaque and default")

-- Mouse move and resize. These also rearrange and resize tiled windows.
section("Windows")
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), "Move or rearrange window", { mouse = true })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), "Resize window", { mouse = true })
bind(mainMod .. " + SHIFT + mouse:273", hl.dsp.window.resize({ keep_aspect_ratio = true }), "Resize window with aspect ratio", { mouse = true })

bind(mainMod .. " + SHIFT + Space", function()
    local workspace = hl.get_active_workspace()
    if workspace == nil then
        return
    end

    local windows = hl.get_workspace_windows(workspace)
    local action = "disable"
    for _, window in ipairs(windows) do
        if not window.floating then
            action = "enable"
            break
        end
    end

    for _, window in ipairs(windows) do
        hl.dispatch(hl.dsp.window.float({ action = action, window = window }))
    end
end, "Toggle all workspace windows floating or tiled")

-- Focus, move, swap, and resize using arrow keys.
local directions = {
    left = "l",
    right = "r",
    up = "u",
    down = "d",
}

section("Focus & move")
for key, direction in pairs(directions) do
    bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = direction }), "Focus window " .. key)
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = direction, group_aware = true }), "Move window " .. key)
    bind(mainMod .. " + ALT + " .. key, hl.dsp.window.swap({ direction = direction }), "Swap tiled window " .. key)
end

section("Focus & move")
bind(mainMod .. " + CTRL + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), "Resize window narrower", { repeating = true })
bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), "Resize window wider", { repeating = true })
bind(mainMod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), "Resize window shorter", { repeating = true })
bind(mainMod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), "Resize window taller", { repeating = true })

for key, direction in pairs(directions) do
    local dx = direction == "l" and -40 or direction == "r" and 40 or 0
    local dy = direction == "u" and -40 or direction == "d" and 40 or 0
    bind(mainMod .. " + CTRL + ALT + " .. key, hl.dsp.window.move({ x = dx, y = dy, relative = true }), "Move floating window " .. key, { repeating = true })
end

section("Layout")
bind(mainMod .. " + CTRL + H", hl.dsp.layout("preselect l"), "Preselect next split left")
bind(mainMod .. " + CTRL + L", hl.dsp.layout("preselect r"), "Preselect next split right")
bind(mainMod .. " + CTRL + K", hl.dsp.layout("preselect u"), "Preselect next split up")
bind(mainMod .. " + CTRL + J", hl.dsp.layout("preselect d"), "Preselect next split down")

-- Floating-window placement. Positions use the active monitor's coordinates
-- and leave room for Waybar and outer gaps.
local function place_window(column, row, width_fraction, height_fraction)
    return function()
        local monitor = hl.get_active_monitor()
        local window = hl.get_active_window()
        if monitor == nil or window == nil then
            return
        end

        hl.dispatch(hl.dsp.window.float({ action = "set" }))

        local gap = 6
        local top = 36
        local usable_width = monitor.width - gap * 2
        local usable_height = monitor.height - top - gap
        local width = math.floor(usable_width * width_fraction)
        local height = math.floor(usable_height * height_fraction)
        local x = monitor.x + gap + math.floor((usable_width - width) * column)
        local y = monitor.y + top + math.floor((usable_height - height) * row)

        hl.dispatch(hl.dsp.window.resize({ x = width, y = height, relative = false }))
        hl.dispatch(hl.dsp.window.move({ x = x, y = y, relative = false }))
    end
end

section("Layout")
bind(mainMod .. " + ALT + H", place_window(0, 0, 0.5, 1), "Place window on left half")
bind(mainMod .. " + ALT + L", place_window(1, 0, 0.5, 1), "Place window on right half")
bind(mainMod .. " + ALT + K", place_window(0, 0, 1, 0.5), "Place window on top half")
bind(mainMod .. " + ALT + J", place_window(0, 1, 1, 0.5), "Place window on bottom half")
bind(mainMod .. " + ALT + U", place_window(0, 0, 0.5, 0.5), "Place window in top-left corner")
bind(mainMod .. " + ALT + I", place_window(1, 0, 0.5, 0.5), "Place window in top-right corner")
bind(mainMod .. " + ALT + N", place_window(0, 1, 0.5, 0.5), "Place window in bottom-left corner")
bind(mainMod .. " + ALT + comma", place_window(1, 1, 0.5, 0.5), "Place window in bottom-right corner")

-- Window cycling and groups
section("Focus & move")
bind("ALT + Tab", hl.dsp.window.cycle_next({ next = true }), "Focus next window")
bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }), "Focus previous window")
section("Workspaces")
bind(mainMod .. " + Tab", launch(scripts .. "/workspace-overview.sh toggle"), "Open workspace and window overview")
bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "previous" }), "Toggle to previous workspace")

-- HyprExpo activates this submap while its overview is open. Arrow keys move
-- between workspace previews, Enter selects one, and Escape closes the view.
section("Overview")
hl.define_submap("hyprexpo", function()
    bind("left", function() hl.plugin.hyprexpo.kb_focus("left") end, "move left")
    bind("right", function() hl.plugin.hyprexpo.kb_focus("right") end, "move right")
    bind("up", function() hl.plugin.hyprexpo.kb_focus("up") end, "move up")
    bind("down", function() hl.plugin.hyprexpo.kb_focus("down") end, "move down")
    bind("h", function() hl.plugin.hyprexpo.kb_focus("left") end, "move left")
    bind("l", function() hl.plugin.hyprexpo.kb_focus("right") end, "move right")
    bind("k", function() hl.plugin.hyprexpo.kb_focus("up") end, "move up")
    bind("j", function() hl.plugin.hyprexpo.kb_focus("down") end, "move down")
    bind("return", function() hl.plugin.hyprexpo.kb_confirm() end, "select workspace")
    bind("space", function() hl.plugin.hyprexpo.kb_confirm() end, "select workspace")
    bind("escape", function() hl.plugin.hyprexpo.expo("cancel") end, "close")
end)
section("Layout")
bind(mainMod .. " + G", hl.dsp.group.toggle(), "Toggle tabbed window group")
local game_mode = false
section("Desktop")
bind(mainMod .. " + CTRL + G", function()
    game_mode = not game_mode
    hl.config({
        animations = { enabled = not game_mode },
        decoration = {
            blur = { enabled = not game_mode },
            shadow = { enabled = not game_mode },
        },
    })
    hl.notification.create({
        text = game_mode and "Performance mode enabled" or "Performance mode disabled",
        timeout = 2500,
    })
end, "Toggle performance mode")
section("Layout")
bind(mainMod .. " + bracketright", hl.dsp.group.next(), "Next window in group")
bind(mainMod .. " + bracketleft", hl.dsp.group.prev(), "Previous window in group")

-- Workspaces 1-10. Shift moves and follows; Ctrl moves silently.
section("Workspaces")
for i = 1, 10 do
    local key = i % 10
    bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }), "Switch to workspace " .. i)
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }), "Move window and follow to workspace " .. i)
    bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.move({ workspace = i, follow = false }), "Move window silently to workspace " .. i)
end

-- Workspaces 11-20 on the same digits with Alt added.
for i = 11, 20 do
    local key = i % 10
    bind(mainMod .. " + ALT + " .. key, hl.dsp.focus({ workspace = i }), "Switch to workspace " .. i)
    bind(mainMod .. " + ALT + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }), "Move window and follow to workspace " .. i)
    bind(mainMod .. " + ALT + CTRL + " .. key, hl.dsp.window.move({ workspace = i, follow = false }), "Move window silently to workspace " .. i)
end
bind(mainMod .. " + ALT + Tab", launch(scripts .. "/workspace-menu.sh"), "Switch, create, rename, or move to named workspaces")

bind(mainMod .. " + Page_Down", hl.dsp.focus({ workspace = "e+1" }), "Next occupied workspace")
bind(mainMod .. " + Page_Up", hl.dsp.focus({ workspace = "e-1" }), "Previous occupied workspace")
-- Keypad 3/9 with Num Lock off send their own keysyms, not Page_Down/Page_Up.
bind(mainMod .. " + KP_Next", hl.dsp.focus({ workspace = "e+1" }), "Next occupied workspace")
bind(mainMod .. " + KP_Prior", hl.dsp.focus({ workspace = "e-1" }), "Previous occupied workspace")
bind(mainMod .. " + N", hl.dsp.focus({ workspace = "empty" }), "Switch to nearest empty workspace")
bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("scratchpad"), "Toggle scratchpad")
-- Super+Shift+S is taken by the laptop's PrtSc key (see Screenshots below).
bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }), "Send window to scratchpad")
bind(mainMod .. " + I", hl.dsp.workspace.toggle_special("scratchpad2"), "Toggle second scratchpad")
bind(mainMod .. " + ALT + I", hl.dsp.window.move({ workspace = "special:scratchpad2", follow = false }), "Send window to second scratchpad")
section("Apps")
bind(mainMod .. " + Return", launch("kitty --class dropdown-terminal"), "Open dropdown terminal")
bind(mainMod .. " + H", hl.dsp.workspace.toggle_special("ncspot"), "Toggle music player scratchpad")

-- Monitor navigation. Relative monitor selectors follow monitor order.
section("Monitors")
bind(mainMod .. " + period", hl.dsp.focus({ monitor = "+1" }), "Focus next monitor")
bind(mainMod .. " + comma", hl.dsp.focus({ monitor = "-1" }), "Focus previous monitor")
bind(mainMod .. " + SHIFT + period", hl.dsp.window.move({ monitor = "+1", follow = true }), "Move window to next monitor")
bind(mainMod .. " + SHIFT + comma", hl.dsp.window.move({ monitor = "-1", follow = true }), "Move window to previous monitor")
bind(mainMod .. " + CTRL + period", hl.dsp.workspace.move({ monitor = "+1" }), "Move workspace to next monitor")
bind(mainMod .. " + CTRL + comma", hl.dsp.workspace.move({ monitor = "-1" }), "Move workspace to previous monitor")

-- Mouse wheel changes workspaces. Ctrl+Super preserves compositor zoom.
section("Workspaces")
bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Next occupied workspace")
bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "Previous occupied workspace")

local function zoom(value)
    return function()
        local current = hl.get_config("cursor.zoom_factor") or 1.0
        hl.config({ cursor = { zoom_factor = math.max(1.0, math.min(2.0, current + value)) } })
    end
end

section("Desktop")
bind(mainMod .. " + CTRL + mouse_down", zoom(-0.2), "Zoom compositor out", { repeating = true })
bind(mainMod .. " + CTRL + mouse_up", zoom(0.2), "Zoom compositor in", { repeating = true })

-- Universal copy, paste, and cut (from Omarchy). Super+C/V/X send the
-- matching clipboard chord to the focused window; terminals get
-- Ctrl+Insert/Shift+Insert so Ctrl+C keeps meaning interrupt. Key down and up
-- are sent separately because send_shortcut can leave synthetic keys stuck:
-- https://github.com/hyprwm/Hyprland/discussions/14099
local terminal_classes = {
    ["kitty"] = true,
    ["dropdown-terminal"] = true,
    ["dotfiles-ncspot"] = true,
    ["dotfiles-btop"] = true,
    ["Alacritty"] = true,
    ["foot"] = true,
    ["com.mitchellh.ghostty"] = true,
    ["org.wezfurlong.wezterm"] = true,
}

local function send_shortcut_once(mods, key)
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
        hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
end

local function universal_clipboard(mods, key, terminal_mods, terminal_key)
    return function()
        local window = hl.get_active_window()
        if window ~= nil and terminal_classes[window.class] then
            send_shortcut_once(terminal_mods, terminal_key)
        else
            send_shortcut_once(mods, key)
        end
    end
end

section("Clipboard")
bind(mainMod .. " + C", universal_clipboard("CTRL", "C", "CTRL", "Insert"), "Universal copy")
bind(mainMod .. " + V", universal_clipboard("CTRL", "V", "SHIFT", "Insert"), "Universal paste")
bind(mainMod .. " + X", universal_clipboard("CTRL", "X", "CTRL", "X"), "Universal cut")

-- Bar, clipboard, wallpaper, and reload actions
section("Desktop")
bind(mainMod .. " + SHIFT + W", launch(scripts .. "/waybar-toggle.sh"), "Toggle Waybar")
section("Clipboard")
bind(mainMod .. " + CTRL + V", launch(scripts .. "/clipboard.sh"), "Search and paste clipboard history")
section("Tools")
bind(mainMod .. " + CTRL + T", launch(scripts .. "/transcode.sh"), "Transcode a picture or video")
bind(mainMod .. " + CTRL + P", launch(scripts .. "/package-manager.sh"), "Open package manager")
section("Desktop")
bind(mainMod .. " + CTRL + D", launch(scripts .. "/defaults-menu.sh"), "Choose default applications")
section("Apps")
bind(mainMod .. " + CTRL + E", launch(scripts .. "/default-launcher.sh editor"), "Open default code editor")
bind(mainMod .. " + SHIFT + V", launch(scripts .. "/vm-manager.sh"), "Open virtual machine manager")
section("Appearance")
bind(mainMod .. " + W", launch("quickshell -n -c hyprquickpaper"), "Choose wallpaper")
bind(mainMod .. " + ALT + W", launch(scripts .. "/wallpaper-cycle.sh random"), "Set random wallpaper")
bind(mainMod .. " + ALT + Page_Down", launch(scripts .. "/wallpaper-cycle.sh next"), "Set next wallpaper")
bind(mainMod .. " + ALT + Page_Up", launch(scripts .. "/wallpaper-cycle.sh previous"), "Set previous wallpaper")
bind(mainMod .. " + SHIFT + T", launch(home .. "/.config/themes/picker.sh"), "Choose desktop theme")
section("Desktop")
bind(mainMod .. " + CTRL + R", launch(scripts .. "/reload-desktop.sh"), "Reload desktop configuration")

-- Screenshots, recording, and color picker
section("Capture")
bind("Print", launch(scripts .. "/screenshot.sh full"), "Capture full screen")
bind("SHIFT + Print", launch(scripts .. "/screenshot.sh area"), "Capture selected region")
bind("ALT + Print", launch(scripts .. "/screenshot.sh window"), "Capture active window")
bind("CTRL + Print", launch(scripts .. "/screenshot.sh area-copy"), "Copy selected region")
bind(mainMod .. " + Print", launch(scripts .. "/screenshot.sh annotate"), "Capture and annotate selected region")
bind(mainMod .. " + CTRL + Print", launch(scripts .. "/screenshot.sh ocr"), "Copy text from selected region")
bind(mainMod .. " + ALT + Print", launch(scripts .. "/screenshot.sh delay"), "Capture screen after five seconds")
-- The built-in Lenovo keyboard's PrtSc key sends Super+Shift+S in firmware, not Print.
bind(mainMod .. " + SHIFT + S", launch(scripts .. "/screenshot.sh area"), "Capture selected region (laptop PrtSc)")
bind(mainMod .. " + CTRL + SHIFT + S", launch(scripts .. "/screenshot.sh area-copy"), "Copy selected region (laptop Ctrl+PrtSc)")
bind(mainMod .. " + ALT + SHIFT + S", launch(scripts .. "/screenshot.sh window"), "Capture active window (laptop Alt+PrtSc)")
bind(mainMod .. " + SHIFT + R", launch(scripts .. "/record-toggle.sh"), "Start or stop screen recording")
bind(mainMod .. " + SHIFT + C", launch(scripts .. "/color-picker.sh"), "Pick color from screen")
section("Notifications")
bind(mainMod .. " + CTRL + ALT + N", launch("dunstctl history-pop"), "Show last notification")
bind(mainMod .. " + CTRL + N", launch("dunstctl set-paused toggle"), "Toggle do not disturb")
bind(mainMod .. " + CTRL + SHIFT + N", launch("sh -c 'dunstctl close-all; dunstctl history-clear'"), "Clear all notifications")

-- Brightness, volume, microphone, and media keys
section("Hardware keys")
bind("XF86MonBrightnessUp", launch("brightnessctl -e4 -n2 set 5%+"), "Increase brightness", { locked = true, repeating = true })
bind("XF86MonBrightnessDown", launch("brightnessctl -e4 -n2 set 5%-"), "Decrease brightness", { locked = true, repeating = true })
bind("XF86AudioRaiseVolume", launch("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), "Increase volume", { locked = true, repeating = true })
bind("XF86AudioLowerVolume", launch("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), "Decrease volume", { locked = true, repeating = true })
bind("XF86AudioMute", launch("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), "Mute audio", { locked = true })
bind("XF86AudioMicMute", launch("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), "Mute microphone", { locked = true })
bind("XF86AudioPlay", launch("playerctl play-pause"), "Play or pause media", { locked = true })
bind("XF86AudioPause", launch("playerctl play-pause"), "Play or pause media", { locked = true })
bind("XF86AudioNext", launch("playerctl next"), "Next media track", { locked = true })
bind("XF86AudioPrev", launch("playerctl previous"), "Previous media track", { locked = true })
