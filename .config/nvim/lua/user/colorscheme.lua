local ok, monokai = pcall(require, "monokai-pro")

if ok and monokai.setup then
  monokai.setup({})
end

vim.cmd("colorscheme monokai-pro")
