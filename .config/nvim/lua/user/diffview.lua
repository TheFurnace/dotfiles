local ok, diffview = pcall(require, "diffview")

if not ok then
  return
end

diffview.setup({})

local map = vim.keymap.set
local opts = { silent = true }

map("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", vim.tbl_extend("force", opts, { desc = "Open diff view" }))
map("n", "<leader>gH", "<cmd>DiffviewFileHistory<cr>", vim.tbl_extend("force", opts, { desc = "Repo file history" }))
map("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", vim.tbl_extend("force", opts, { desc = "Current file history" }))
map("n", "<leader>gq", "<cmd>DiffviewClose<cr>", vim.tbl_extend("force", opts, { desc = "Close diff view" }))
