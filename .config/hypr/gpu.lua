-- Load installer-generated, machine-local DRM device priority when available.
-- Keeping this separate from visual configuration lets the same repository be
-- installed on systems without hybrid graphics.
local loaded, devices = pcall(require, "gpu.local")

if loaded and type(devices) == "table" and #devices > 0 then
    hl.env("AQ_DRM_DEVICES", table.concat(devices, ":"))
end
