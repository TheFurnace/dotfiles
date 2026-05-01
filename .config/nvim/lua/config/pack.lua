vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.pack.add({
  {
    src = "https://github.com/loctvl842/monokai-pro.nvim",
    name = "monokai-pro.nvim",
  },
  {
    src = "https://github.com/nvim-treesitter/nvim-treesitter",
    version = "v0.10.0",
  },
  {
    src = "https://github.com/nvim-lua/plenary.nvim",
  },
  {
    src = "https://github.com/nvim-telescope/telescope.nvim",
    version = "0.1.x",
  },
  {
    src = "https://github.com/sindrets/diffview.nvim",
  },
  {
    src = "https://github.com/mrcjkb/rustaceanvim",
    version = "^5",
  },
  {
    src = "https://github.com/hrsh7th/nvim-cmp",
  },
  {
    src = "https://github.com/hrsh7th/cmp-nvim-lsp",
  },
  {
    src = "https://github.com/hrsh7th/cmp-buffer",
  },
  {
    src = "https://github.com/hrsh7th/cmp-path",
  },
  {
    src = "https://github.com/stevearc/conform.nvim",
  },
}, {
  confirm = false,
})
