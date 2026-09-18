-- Portable fallback. A machine-local module can override this after the real
-- output names and modes have been collected with `hyprctl monitors all`.
local loaded, machine = pcall(require, "machine")

if loaded and type(machine) == "table" and type(machine.monitors) == "table" then
    for _, monitor in ipairs(machine.monitors) do
        hl.monitor(monitor)
    end
end

-- Covers external displays and remains the safe rule when no local config has
-- been generated yet.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
