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
}, {
  confirm = false,
})
