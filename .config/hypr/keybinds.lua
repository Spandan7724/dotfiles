-- ~/.config/hypr/keybinds.lua
-- Hyprland 0.56 Lua dispatcher API:
-- https://wiki.hypr.land/Configuring/Basics/Dispatchers/

local home = os.getenv("HOME")
local scripts = home .. "/.config/hypr/scripts"

local function bind(keys, dispatcher, description, options)
    options = options or {}
    options.description = description
    hl.bind(keys, dispatcher, options)
end

local function launch(command)
    return hl.dsp.exec_cmd(command)
end

-- Launchers and desktop panels
bind(mainMod .. " + T", launch(scripts .. "/default-launcher.sh terminal"), "Open default terminal")
bind(mainMod .. " + D", launch(scripts .. "/apps-menu.sh"), "Open applications menu")
bind(mainMod .. " + E", launch(scripts .. "/default-launcher.sh file-manager"), "Open default file manager")
bind(mainMod .. " + B", launch(scripts .. "/default-launcher.sh browser"), "Open default browser")
bind(mainMod .. " + X", launch(scripts .. "/control-center.sh"), "Open quick settings")
bind(mainMod .. " + F1", launch(scripts .. "/keybinds.sh"), "Show keyboard shortcuts")
bind(mainMod .. " + F2", launch(scripts .. "/desktop-menu.sh"), "Open desktop control menu")
bind(mainMod .. " + ALT + Space", launch(scripts .. "/desktop-menu.sh"), "Open desktop control menu")
bind(mainMod .. " + Escape", launch(scripts .. "/desktop-menu.sh"), "Open desktop control menu")
bind(mainMod .. " + slash", launch(scripts .. "/keybinds.sh"), "Search keyboard shortcuts")
bind(mainMod .. " + SHIFT + slash", launch(scripts .. "/hyprmod-launch.sh"), "Open advanced Hyprland settings")
bind(mainMod .. " + A", launch("pavucontrol"), "Open audio settings")
bind(mainMod .. " + SHIFT + B", launch(terminal .. " --class dotfiles-btop -e btop"), "Open system monitor")
bind(mainMod .. " + R", launch(scripts .. "/file-search.sh"), "Search files")
bind(mainMod .. " + SHIFT + D", launch(scripts .. "/web-search.sh"), "Search the web")
bind(mainMod .. " + equal", launch(scripts .. "/calculator.sh"), "Open calculator")
bind(mainMod .. " + semicolon", launch("rofimoji --action copy"), "Choose emoji or symbol")
bind(mainMod .. " + CTRL + W", launch("nm-connection-editor"), "Open Wi-Fi and network settings")
bind(mainMod .. " + CTRL + B", launch("blueman-manager"), "Open Bluetooth settings")

-- Session and window state
bind(mainMod .. " + Q", hl.dsp.window.close(), "Close active window")
bind(mainMod .. " + SHIFT + Q", hl.dsp.window.kill(), "Force-kill active window")
bind(mainMod .. " + L", launch("hyprlock"), "Lock session")
bind(mainMod .. " + GRAVE", launch(scripts .. "/power-menu.sh"), "Open power and session menu")
bind(mainMod .. " + SHIFT + E", hl.dsp.exit(), "Exit Hyprland")
bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), "Toggle fullscreen")
bind(mainMod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), "Toggle maximize")
bind(mainMod .. " + Space", hl.dsp.window.float({ action = "toggle" }), "Toggle floating")
bind(mainMod .. " + C", hl.dsp.window.center(), "Center floating window")
bind(mainMod .. " + P", hl.dsp.window.pseudo({ action = "toggle" }), "Toggle pseudotile")
bind(mainMod .. " + SHIFT + P", hl.dsp.window.pin({ action = "toggle" }), "Pin floating window")
bind(mainMod .. " + backslash", hl.dsp.layout("togglesplit"), "Toggle dwindle split direction")
bind(mainMod .. " + SHIFT + backslash", hl.dsp.layout("swapsplit"), "Swap the two halves of the current split")
bind(mainMod .. " + SHIFT + minus", hl.dsp.layout("splitratio -0.05"), "Shrink current split", { repeating = true })
bind(mainMod .. " + SHIFT + equal", hl.dsp.layout("splitratio +0.05"), "Grow current split", { repeating = true })
local opacity_steps = { 1.0, 0.9, 0.8, 0.7 }
local opacity_index = {}

bind(mainMod .. " + O", function()
    local window = hl.get_active_window()
    if window == nil then
        return
    end

    local next_index = (opacity_index[window.address] or 1) + 1
    if next_index > #opacity_steps then
        next_index = 1
    end
    opacity_index[window.address] = next_index
    hl.dispatch(hl.dsp.window.set_prop({
        prop = "opacity",
        value = tostring(opacity_steps[next_index]) .. " override",
    }))
end, "Cycle active-window opacity")

-- Mouse move and resize. These also rearrange and resize tiled windows.
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

for key, direction in pairs(directions) do
    bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = direction }), "Focus window " .. key)
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = direction, group_aware = true }), "Move window " .. key)
    bind(mainMod .. " + ALT + " .. key, hl.dsp.window.swap({ direction = direction }), "Swap tiled window " .. key)
end

bind(mainMod .. " + CTRL + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), "Resize window narrower", { repeating = true })
bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), "Resize window wider", { repeating = true })
bind(mainMod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), "Resize window shorter", { repeating = true })
bind(mainMod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), "Resize window taller", { repeating = true })

for key, direction in pairs(directions) do
    local dx = direction == "l" and -40 or direction == "r" and 40 or 0
    local dy = direction == "u" and -40 or direction == "d" and 40 or 0
    bind(mainMod .. " + CTRL + ALT + " .. key, hl.dsp.window.move({ x = dx, y = dy, relative = true }), "Move floating window " .. key, { repeating = true })
end

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

bind(mainMod .. " + ALT + H", place_window(0, 0, 0.5, 1), "Place window on left half")
bind(mainMod .. " + ALT + L", place_window(1, 0, 0.5, 1), "Place window on right half")
bind(mainMod .. " + ALT + K", place_window(0, 0, 1, 0.5), "Place window on top half")
bind(mainMod .. " + ALT + J", place_window(0, 1, 1, 0.5), "Place window on bottom half")
bind(mainMod .. " + ALT + U", place_window(0, 0, 0.5, 0.5), "Place window in top-left corner")
bind(mainMod .. " + ALT + I", place_window(1, 0, 0.5, 0.5), "Place window in top-right corner")
bind(mainMod .. " + ALT + N", place_window(0, 1, 0.5, 0.5), "Place window in bottom-left corner")
bind(mainMod .. " + ALT + comma", place_window(1, 1, 0.5, 0.5), "Place window in bottom-right corner")

-- Window cycling and groups
bind("ALT + Tab", hl.dsp.window.cycle_next({ next = true }), "Focus next window")
bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }), "Focus previous window")
bind(mainMod .. " + Tab", launch(scripts .. "/workspace-overview.sh toggle"), "Open workspace and window overview")

-- HyprExpo activates this submap while its overview is open. Arrow keys move
-- between workspace previews, Enter selects one, and Escape closes the view.
hl.define_submap("hyprexpo", function()
    bind("left", function() hl.plugin.hyprexpo.kb_focus("left") end, "Overview: move left")
    bind("right", function() hl.plugin.hyprexpo.kb_focus("right") end, "Overview: move right")
    bind("up", function() hl.plugin.hyprexpo.kb_focus("up") end, "Overview: move up")
    bind("down", function() hl.plugin.hyprexpo.kb_focus("down") end, "Overview: move down")
    bind("h", function() hl.plugin.hyprexpo.kb_focus("left") end, "Overview: move left")
    bind("l", function() hl.plugin.hyprexpo.kb_focus("right") end, "Overview: move right")
    bind("k", function() hl.plugin.hyprexpo.kb_focus("up") end, "Overview: move up")
    bind("j", function() hl.plugin.hyprexpo.kb_focus("down") end, "Overview: move down")
    bind("return", function() hl.plugin.hyprexpo.kb_confirm() end, "Overview: select workspace")
    bind("space", function() hl.plugin.hyprexpo.kb_confirm() end, "Overview: select workspace")
    bind("escape", function() hl.plugin.hyprexpo.expo("cancel") end, "Overview: close")
end)
bind(mainMod .. " + G", hl.dsp.group.toggle(), "Toggle tabbed window group")
local game_mode = false
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
bind(mainMod .. " + bracketright", hl.dsp.group.next(), "Next window in group")
bind(mainMod .. " + bracketleft", hl.dsp.group.prev(), "Previous window in group")

-- Workspaces 1-10. Shift moves and follows; Ctrl moves silently.
for i = 1, 10 do
    local key = i % 10
    bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }), "Switch to workspace " .. i)
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }), "Move window and follow to workspace " .. i)
    bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.move({ workspace = i, follow = false }), "Move window silently to workspace " .. i)
end

bind(mainMod .. " + Page_Down", hl.dsp.focus({ workspace = "e+1" }), "Next occupied workspace")
bind(mainMod .. " + Page_Up", hl.dsp.focus({ workspace = "e-1" }), "Previous occupied workspace")
bind(mainMod .. " + N", hl.dsp.focus({ workspace = "empty" }), "Switch to nearest empty workspace")
bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("scratchpad"), "Toggle scratchpad")
bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }), "Send window to scratchpad")
bind(mainMod .. " + Return", launch("kitty --class dropdown-terminal"), "Open dropdown terminal")

-- Monitor navigation. Relative monitor selectors follow monitor order.
bind(mainMod .. " + period", hl.dsp.focus({ monitor = "+1" }), "Focus next monitor")
bind(mainMod .. " + comma", hl.dsp.focus({ monitor = "-1" }), "Focus previous monitor")
bind(mainMod .. " + SHIFT + period", hl.dsp.window.move({ monitor = "+1", follow = true }), "Move window to next monitor")
bind(mainMod .. " + SHIFT + comma", hl.dsp.window.move({ monitor = "-1", follow = true }), "Move window to previous monitor")
bind(mainMod .. " + CTRL + period", hl.dsp.workspace.move({ monitor = "+1" }), "Move workspace to next monitor")
bind(mainMod .. " + CTRL + comma", hl.dsp.workspace.move({ monitor = "-1" }), "Move workspace to previous monitor")

-- Mouse wheel changes workspaces. Ctrl+Super preserves compositor zoom.
bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Next occupied workspace")
bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "Previous occupied workspace")

local function zoom(value)
    return function()
        local current = hl.get_config("cursor.zoom_factor") or 1.0
        hl.config({ cursor = { zoom_factor = math.max(1.0, math.min(2.0, current + value)) } })
    end
end

bind(mainMod .. " + CTRL + mouse_down", zoom(-0.2), "Zoom compositor out", { repeating = true })
bind(mainMod .. " + CTRL + mouse_up", zoom(0.2), "Zoom compositor in", { repeating = true })

-- Bar, clipboard, wallpaper, and reload actions
bind(mainMod .. " + SHIFT + W", launch(scripts .. "/waybar-toggle.sh"), "Toggle Waybar")
bind(mainMod .. " + V", launch(scripts .. "/clipboard.sh"), "Search and paste clipboard history")
bind(mainMod .. " + CTRL + T", launch(scripts .. "/transcode.sh"), "Transcode a picture or video")
bind(mainMod .. " + CTRL + P", launch(scripts .. "/package-manager.sh"), "Open package manager")
bind(mainMod .. " + CTRL + D", launch(scripts .. "/defaults-menu.sh"), "Choose default applications")
bind(mainMod .. " + CTRL + E", launch(scripts .. "/default-launcher.sh editor"), "Open default code editor")
bind(mainMod .. " + SHIFT + V", launch(scripts .. "/vm-manager.sh"), "Open virtual machine manager")
bind(mainMod .. " + W", launch("quickshell -n -c hyprquickpaper"), "Choose wallpaper")
bind(mainMod .. " + ALT + W", launch(scripts .. "/wallpaper-cycle.sh random"), "Set random wallpaper")
bind(mainMod .. " + ALT + Page_Down", launch(scripts .. "/wallpaper-cycle.sh next"), "Set next wallpaper")
bind(mainMod .. " + ALT + Page_Up", launch(scripts .. "/wallpaper-cycle.sh previous"), "Set previous wallpaper")
bind(mainMod .. " + SHIFT + T", launch(home .. "/.config/themes/picker.sh"), "Choose desktop theme")
bind(mainMod .. " + CTRL + R", launch(scripts .. "/reload-desktop.sh"), "Reload desktop configuration")

-- Screenshots, recording, and color picker
bind("Print", launch(scripts .. "/screenshot.sh full"), "Capture full screen")
bind("SHIFT + Print", launch(scripts .. "/screenshot.sh area"), "Capture selected region")
bind("ALT + Print", launch(scripts .. "/screenshot.sh window"), "Capture active window")
bind("CTRL + Print", launch(scripts .. "/screenshot.sh area-copy"), "Copy selected region")
bind(mainMod .. " + Print", launch(scripts .. "/screenshot.sh annotate"), "Capture and annotate selected region")
bind(mainMod .. " + CTRL + Print", launch(scripts .. "/screenshot.sh ocr"), "Copy text from selected region")
bind(mainMod .. " + ALT + Print", launch(scripts .. "/screenshot.sh delay"), "Capture screen after five seconds")
bind(mainMod .. " + SHIFT + R", launch(scripts .. "/record-toggle.sh"), "Start or stop screen recording")
bind(mainMod .. " + SHIFT + C", launch(scripts .. "/color-picker.sh"), "Pick color from screen")
bind(mainMod .. " + SHIFT + N", launch("dunstctl history-pop"), "Show last notification")
bind(mainMod .. " + CTRL + N", launch("dunstctl set-paused toggle"), "Toggle do not disturb")
bind(mainMod .. " + CTRL + SHIFT + N", launch("sh -c 'dunstctl close-all; dunstctl history-clear'"), "Clear all notifications")

-- Brightness, volume, microphone, and media keys
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
