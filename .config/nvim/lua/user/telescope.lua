local ok, telescope = pcall(require, "telescope")

if not ok then
  return
end

telescope.setup({})

local builtin = require("telescope.builtin")
local map = vim.keymap.set
local opts = { silent = true }

map("n", "<leader>ff", builtin.find_files, vim.tbl_extend("force", opts, { desc = "Find files" }))
map("n", "<leader>fg", builtin.live_grep, vim.tbl_extend("force", opts, { desc = "Live grep" }))
map("n", "<leader>fb", builtin.buffers, vim.tbl_extend("force", opts, { desc = "Buffers" }))
map("n", "<leader>fh", builtin.help_tags, vim.tbl_extend("force", opts, { desc = "Help tags" }))
