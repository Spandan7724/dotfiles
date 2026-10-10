-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

-- The theme follows the desktop theme (~/.config/themes, Super+Shift+T). Its
-- nvim.lua names a base46 theme; "dotfiles" is the palette-generated one in
-- lua/themes/dotfiles.lua.
local function desktop_theme()
	local ok, name = pcall(dofile, vim.fn.expand "~/.config/themes/current/nvim.lua")
	return ok and type(name) == "string" and name or "onedark"
end

M.base46 = {
	theme = desktop_theme(),

	-- hl_override = {
	-- 	Comment = { italic = true },
	-- 	["@comment"] = { italic = true },
	-- },
}

-- M.nvdash = { load_on_startup = true }
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
-- }

return M
