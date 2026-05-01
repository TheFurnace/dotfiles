local opt = vim.opt

opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4

local filetype_widths = {
  lua = 2,
  javascript = 2,
  javascriptreact = 2,
  typescript = 2,
  typescriptreact = 2,
  json = 2,
  jsonc = 2,
  yaml = 2,
  nix = 2,

  python = 4,
  rust = 4,
  cs = 4,
  c = 4,
  cpp = 4,
  fish = 4,
  sh = 4,
  bash = 4,
}

local function set_indent(bufnr, width, expandtab)
  vim.bo[bufnr].expandtab = expandtab
  vim.bo[bufnr].tabstop = width
  vim.bo[bufnr].shiftwidth = width
  vim.bo[bufnr].softtabstop = width
end

local function apply_filetype_default(bufnr)
  local width = filetype_widths[vim.bo[bufnr].filetype]

  if width then
    set_indent(bufnr, width, true)
  end
end

local function gcd(a, b)
  while b ~= 0 do
    a, b = b, a % b
  end

  return a
end

local function normalize_width(width)
  if width == nil or width <= 1 then
    return nil
  end

  if width % 4 == 0 then
    return 4
  end

  if width % 2 == 0 then
    return 2
  end

  if width == 8 then
    return 8
  end

  return nil
end

local function detect_indent(bufnr)
  if vim.bo[bufnr].buftype ~= "" then
    return nil
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)

  if line_count == 0 then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, math.min(line_count, 250), false)
  local tab_indented = 0
  local space_indented = 0
  local space_gcd = 0

  for _, line in ipairs(lines) do
    if line:find("%S") then
      local leading = line:match("^(%s+)")

      if leading then
        if leading:find("^	+") then
          tab_indented = tab_indented + 1
        elseif leading:find("^ +$") then
          local width = #leading

          if width > 1 then
            space_indented = space_indented + 1
            space_gcd = space_gcd == 0 and width or gcd(space_gcd, width)
          end
        end
      end
    end
  end

  if tab_indented > 0 and tab_indented > space_indented then
    return {
      width = 4,
      expandtab = false,
    }
  end

  local width = normalize_width(space_gcd)

  if space_indented > 0 and width then
    return {
      width = width,
      expandtab = true,
    }
  end

  return nil
end

local group = vim.api.nvim_create_augroup("user-indent", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "*",
  callback = function(args)
    apply_filetype_default(args.buf)

    local detected = detect_indent(args.buf)
    if detected then
      set_indent(args.buf, detected.width, detected.expandtab)
    end
  end,
})
