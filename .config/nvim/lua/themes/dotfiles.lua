-- base46 theme generated from the desktop theme's palette. themes/generate.py
-- writes ~/.config/themes/<theme>/base46.lua for themes that have no matching
-- built-in NvChad theme; this module just loads the current one.
local ok, theme = pcall(dofile, vim.fn.expand "~/.config/themes/current/base46.lua")
if ok and type(theme) == "table" then
  return theme
end
return require "base46.themes.onedark"
