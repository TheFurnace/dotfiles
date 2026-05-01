local opt = vim.opt

opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.expandtab = true

local ok, conform = pcall(require, "conform")

if not ok then
  return
end

conform.setup({
  formatters_by_ft = {
    rust = { "rustfmt" },
  },
  format_on_save = function(bufnr)
    if vim.bo[bufnr].filetype ~= "rust" then
      return nil
    end

    if vim.fn.executable("rustfmt") ~= 1 then
      return nil
    end

    return {
      timeout_ms = 500,
      lsp_format = "fallback",
    }
  end,
})

vim.keymap.set("n", "<leader>f", function()
  conform.format({
    async = true,
    lsp_format = "fallback",
  })
end, { silent = true, desc = "Format buffer" })
