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
}, {
  confirm = false,
})
