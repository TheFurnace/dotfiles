require("nvim-treesitter.configs").setup({
  ensure_installed = { "lua", "markdown", "markdown_inline", "bash", "python", "fish", "rust", "toml", "c_sharp" },
  ignore_install = { "" },
  sync_install = false,
  highlight = {
    enable = true,
    disable = { "css" },
  },
  autopairs = {
    enable = true,
  },
  indent = { enable = true, disable = { "python", "css" } },
  context_commentstring = {
    enable = true,
    enable_autocmd = false,
  },
})
