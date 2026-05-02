local capabilities = vim.lsp.protocol.make_client_capabilities()
local ok_cmp_lsp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")

if ok_cmp_lsp then
  capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
end

local function on_attach(client, bufnr)
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
  end

  map("K", vim.lsp.buf.hover, "Hover")
  map("gd", vim.lsp.buf.definition, "Go to definition")
  map("gr", vim.lsp.buf.references, "References")
  map("<leader>ca", vim.lsp.buf.code_action, "Code action")
  map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
  map("<leader>ws", vim.lsp.buf.workspace_symbol, "Workspace symbols")

  if client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
    pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
  end
end

local function find_root(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local start = bufname ~= "" and vim.fs.dirname(bufname) or vim.uv.cwd()

  local marker = vim.fs.find(function(name)
    return name == "flake.nix"
      or name == "default.nix"
      or name == "shell.nix"
      or name == ".git"
  end, {
    upward = true,
    path = start,
  })[1]

  if marker then
    return vim.fs.dirname(marker)
  end

  return start
end

local function server_config(root_dir)
  if vim.fn.executable("nixd") == 1 then
    return {
      name = "nixd",
      cmd = { "nixd" },
      root_dir = root_dir,
    }
  end

  if vim.fn.executable("nil") == 1 then
    return {
      name = "nil_ls",
      cmd = { "nil" },
      root_dir = root_dir,
      settings = {
        ["nil"] = {
          formatting = {
            command = { "alejandra" },
          },
        },
      },
    }
  end
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "nix",
  callback = function(args)
    local root_dir = find_root(args.buf)
    local config = server_config(root_dir)

    if not config then
      return
    end

    vim.lsp.start({
      name = config.name,
      cmd = config.cmd,
      root_dir = config.root_dir,
      capabilities = capabilities,
      on_attach = on_attach,
      settings = config.settings,
    })
  end,
})
