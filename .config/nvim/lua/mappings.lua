require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map({ "n", "v" }, "<leader>lf", function()
  require("conform").format { async = true, lsp_format = "fallback" }
end, { desc = "LSP format file or selection" })

map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "LSP code action" })
map("n", "K", vim.lsp.buf.hover, { desc = "LSP hover documentation" })
map("n", "<leader>lr", vim.lsp.buf.references, { desc = "LSP references" })
map("n", "[d", function()
  vim.diagnostic.jump { count = -1, float = true }
end, { desc = "Previous diagnostic" })
map("n", "]d", function()
  vim.diagnostic.jump { count = 1, float = true }
end, { desc = "Next diagnostic" })
