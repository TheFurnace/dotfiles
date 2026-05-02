local ok, ts = pcall(require, "nvim-treesitter")

if not ok then
  return
end

local install_dir = vim.fn.stdpath("data") .. "/site"

-- Make parser/query installs take precedence over Neovim's built-in runtime.
ts.setup({
  install_dir = install_dir,
})

local languages = {
  "lua",
  "markdown",
  "markdown_inline",
  "bash",
  "python",
  "fish",
  "rust",
  "toml",
  "c_sharp",
  "javascript",
  "typescript",
  "tsx",
  "json",
}

ts.install(languages)

-- Filetype to parser mappings that don't match by name.
vim.treesitter.language.register("c_sharp", "cs")

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user-treesitter", { clear = true }),
  pattern = "*",
  callback = function(args)
    local bufnr = args.buf
    local ft = vim.bo[bufnr].filetype

    if ft == "" then
      return
    end

    local ok_start = pcall(vim.treesitter.start, bufnr)
    if not ok_start then
      return
    end

    if ft ~= "python" and ft ~= "css" then
      vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})
