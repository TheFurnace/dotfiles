local ok, oil = pcall(require, "oil")

if not ok then
  return
end

oil.setup({
  default_file_explorer = true,
  view_options = {
    show_hidden = true,
  },
  float = {
    padding = 4,
    max_width = 0,
    max_height = 0,
    border = "rounded",
  },
})

local map = vim.keymap.set
local opts = { silent = true }

map("n", "-", "<cmd>Oil<cr>", vim.tbl_extend("force", opts, { desc = "Open parent directory" }))
map("n", "<leader>e", "<cmd>Oil --float<cr>", vim.tbl_extend("force", opts, { desc = "Open file explorer" }))
