local treesitter_parsers = {
  "bash",
  "c",
  "cpp",
  "css",
  "go",
  "gomod",
  "gosum",
  "gowork",
  "html",
  "javascript",
  "jsdoc",
  "json",
  "lua",
  "luadoc",
  "markdown",
  "markdown_inline",
  "printf",
  "python",
  "rust",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
}

local treesitter_filetypes = {
  "c",
  "cpp",
  "css",
  "go",
  "gomod",
  "gosum",
  "gowork",
  "html",
  "javascript",
  "javascriptreact",
  "json",
  "jsonc",
  "lua",
  "markdown",
  "python",
  "rust",
  "sh",
  "typescript",
  "typescriptreact",
  "vim",
}

return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    lazy = false,
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      -- Language servers are supplied by system packages; Mason manages the
      -- missing formatter/linter executables used by this config.
      ensure_installed = {
        "ruff",
        "prettier",
        "goimports",
        "gofumpt",
        "eslint-lsp",
        "html-lsp",
        "css-lsp",
      },
      run_on_start = true,
      start_delay = 1000,
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    opts = { ensure_installed = treesitter_parsers },
    config = function(_, opts)
      -- nvim-treesitter's current main branch uses Neovim's native
      -- highlighting and an asynchronous parser installer.
      require("nvim-treesitter").setup()
      require("nvim-treesitter").install(opts.ensure_installed)

      pcall(function()
        dofile(vim.g.base46_cache .. "syntax")
        dofile(vim.g.base46_cache .. "treesitter")
      end)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = treesitter_filetypes,
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },
}
