require("nvchad.configs.lspconfig").defaults()

-- Language-specific settings. NvChad's defaults supply completion
-- capabilities, diagnostics, and the common LSP keymaps.
vim.lsp.config("pyright", {
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        diagnosticMode = "openFilesOnly",
        typeCheckingMode = "basic",
        useLibraryCodeForTypes = true,
      },
    },
  },
})

vim.lsp.config("ruff", {
  init_options = {
    settings = {
      organizeImports = true,
      lint = { enable = true },
    },
  },
  -- Pyright gives richer Python hover information.
  on_attach = function(client)
    client.server_capabilities.hoverProvider = false
  end,
})

vim.lsp.config("gopls", {
  settings = {
    gopls = {
      analyses = {
        nilness = true,
        unusedparams = true,
        unusedwrite = true,
        useany = true,
      },
      completeUnimported = true,
      gofumpt = true,
      staticcheck = true,
      usePlaceholders = true,
    },
  },
})

vim.lsp.config("rust_analyzer", {
  settings = {
    ["rust-analyzer"] = {
      cargo = { allFeatures = true },
      check = { command = "clippy" },
      procMacro = { enable = true },
    },
  },
})

vim.lsp.config("clangd", {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion=iwyu",
  },
})

local ts_inlay_hints = {
  includeInlayEnumMemberValueHints = true,
  includeInlayFunctionLikeReturnTypeHints = true,
  includeInlayFunctionParameterTypeHints = true,
  includeInlayParameterNameHints = "literals",
  includeInlayParameterNameHintsWhenArgumentMatchesName = false,
  includeInlayPropertyDeclarationTypeHints = true,
  includeInlayVariableTypeHints = false,
}

vim.lsp.config("ts_ls", {
  settings = {
    javascript = { inlayHints = ts_inlay_hints },
    typescript = { inlayHints = ts_inlay_hints },
  },
})

vim.lsp.config("eslint", {
  settings = {
    workingDirectory = { mode = "auto" },
  },
})

vim.lsp.enable {
  "pyright",
  "ruff",
  "gopls",
  "rust_analyzer",
  "clangd",
  "ts_ls",
  "eslint",
  "html",
  "cssls",
}
