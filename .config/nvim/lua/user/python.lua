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
    return name == "pyproject.toml"
      or name == "uv.lock"
      or name == "poetry.lock"
      or name == "setup.py"
      or name == "setup.cfg"
      or name == "requirements.txt"
      or name == "pyrightconfig.json"
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

local function server_config()
  if vim.fn.executable("basedpyright-langserver") == 1 then
    return {
      name = "basedpyright",
      cmd = { "basedpyright-langserver", "--stdio" },
      settings = {
        basedpyright = {
          analysis = {
            autoSearchPaths = true,
            useLibraryCodeForTypes = true,
          },
        },
      },
    }
  end

  if vim.fn.executable("pyright-langserver") == 1 then
    return {
      name = "pyright",
      cmd = { "pyright-langserver", "--stdio" },
      settings = {
        python = {
          analysis = {
            autoSearchPaths = true,
            useLibraryCodeForTypes = true,
          },
        },
      },
    }
  end

  if vim.fn.executable("pylsp") == 1 then
    return {
      name = "pylsp",
      cmd = { "pylsp" },
    }
  end

  if vim.fn.executable("jedi-language-server") == 1 then
    return {
      name = "jedi_language_server",
      cmd = { "jedi-language-server" },
    }
  end
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function(args)
    local config = server_config()

    if not config then
      return
    end

    vim.lsp.start({
      name = config.name,
      cmd = config.cmd,
      root_dir = find_root(args.buf),
      capabilities = capabilities,
      on_attach = on_attach,
      settings = config.settings,
    })
  end,
})
