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
    javascript = { "biome", "prettierd", "prettier", stop_after_first = true },
    javascriptreact = { "biome", "prettierd", "prettier", stop_after_first = true },
    typescript = { "biome", "prettierd", "prettier", stop_after_first = true },
    typescriptreact = { "biome", "prettierd", "prettier", stop_after_first = true },
    json = { "biome", "prettierd", "prettier", stop_after_first = true },
    jsonc = { "biome", "prettierd", "prettier", stop_after_first = true },
  },
  format_on_save = function(bufnr)
    local filetype = vim.bo[bufnr].filetype

    if filetype == "rust" then
      if vim.fn.executable("rustfmt") ~= 1 then
        return nil
      end

      return {
        timeout_ms = 500,
        lsp_format = "fallback",
      }
    end

    if filetype == "cs"
      or filetype == "javascript"
      or filetype == "javascriptreact"
      or filetype == "typescript"
      or filetype == "typescriptreact"
      or filetype == "json"
      or filetype == "jsonc" then
      return {
        timeout_ms = 500,
        lsp_format = "fallback",
      }
    end

    return nil
  end,
})

vim.keymap.set("n", "<leader>f", function()
  conform.format({
    async = true,
    lsp_format = "fallback",
  })
end, { silent = true, desc = "Format buffer" })
