require "config.lazy"
require "user.treesitter"

vim.api.nvim_create_user_command('SyntaxHere', function()
	local pos = vim.api.nvim_win_get_cursor(0)
	local line, col = pos[1], pos[2] + 1
	print 'Regex (legacy) Syntax Highlights'
	print '--------------------------------'
	print(' effective: ' .. vim.fn.synIDattr(vim.fn.synID(line, col, true), 'name'))
	for _, synId in ipairs(vim.fn.synstack(line, col)) do
		local synGroupId = vim.fn.synIDtrans(synId)
		print(' ' .. vim.fn.synIDattr(synId, 'name') .. ' -> ' .. vim.fn.synIDattr(synGroupId, 'name'))
	end
	print ' '
	print 'Tree-sitter Syntax Highlights'
	print '--------------------------------'
	vim.print(vim.treesitter.get_captures_at_cursor(0))
end, {})
