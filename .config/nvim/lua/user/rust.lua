local capabilities = vim.lsp.protocol.make_client_capabilities()
local ok_cmp_lsp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")

if ok_cmp_lsp then
  capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
end

local function on_attach(client, bufnr)
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
  end

  map("K", function()
    if vim.fn.exists(":RustLsp") == 2 then
      vim.cmd.RustLsp({ "hover", "actions" })
    else
      vim.lsp.buf.hover()
    end
  end, "Rust hover actions")

  map("gd", vim.lsp.buf.definition, "Go to definition")
  map("gr", vim.lsp.buf.references, "References")
  map("<leader>ca", vim.lsp.buf.code_action, "Code action")
  map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
  map("<leader>rf", function()
    if vim.fn.exists(":RustLsp") == 2 then
      vim.cmd.RustLsp({ "runnables" })
    end
  end, "Rust runnables")

  if client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
    pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
  end
end

vim.g.rustaceanvim = {
  server = {
    capabilities = capabilities,
    on_attach = on_attach,
    default_settings = {
      ["rust-analyzer"] = {
        cargo = {
          allFeatures = true,
        },
        check = {
          command = "clippy",
        },
      },
    },
  },
}
