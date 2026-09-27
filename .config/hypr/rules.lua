-- ~/.config/hypr/rules.lua
-- Migrated from rules.conf
-- Docs: https://wiki.hypr.land/Configuring/Basics/Window-Rules/

hl.layer_rule({
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 0.15,
})

-- Opacity rules: 90% for all windows except fullscreen
hl.window_rule({
    match = { class = ".*" },
    opacity = "0.9 override",
})

hl.window_rule({
    match = { class = ".*", fullscreen = true },
    opacity = "1.0 override",
})

hl.window_rule({
    name = "float-pavucontrol",
    match = { class = "^(pavucontrol)$" },
    float = true,
})

hl.window_rule({
    name = "float-nm-connection-editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
})

hl.window_rule({
    name = "float-blueman-manager",
    match = { class = "^(blueman-manager)$" },
    float = true,
})

hl.window_rule({
    name = "float-open-file",
    match = { title = "^(Open File)$" },
    float = true,
})

hl.window_rule({
    name = "float-save-file",
    match = { title = "^(Save File)$" },
    float = true,
})

hl.window_rule({
    name = "picture-in-picture",
    match = { title = "^([Pp]icture[- ]in[- ][Pp]icture)$" },
    float = true,
    pin = true,
    keep_aspect_ratio = true,
    size = { "(monitor_w*0.32)", "(monitor_h*0.32)" },
    move = { "(monitor_w-window_w-20)", "45" },
})

hl.window_rule({
    name = "dropdown-terminal",
    match = { class = "^(dropdown-terminal)$" },
    float = true,
    center = true,
    size = { "(monitor_w*0.72)", "(monitor_h*0.62)" },
})

hl.window_rule({
    name = "float-system-monitor",
    match = { class = "^(dotfiles-btop)$" },
    float = true,
    center = true,
    size = { "(monitor_w*0.78)", "(monitor_h*0.75)" },
})

hl.window_rule({
    name = "float-system-update",
    match = { class = "^(dotfiles-update)$" },
    float = true,
    center = true,
    size = { "(monitor_w*0.78)", "(monitor_h*0.75)" },
})

hl.window_rule({
    name = "float-desktop-tools",
    match = { class = "^(dotfiles-packages|dotfiles-transcode|dotfiles-security|dotfiles-defaults)$" },
    float = true,
    center = true,
    size = { "(monitor_w*0.80)", "(monitor_h*0.78)" },
})

hl.window_rule({
    name = "idle-inhibit-video",
    match = { class = "^(mpv|zen|zen-browser|Brave-browser|brave-browser)$" },
    idle_inhibit = "fullscreen",
})
