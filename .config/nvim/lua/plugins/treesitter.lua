return {
	"nvim-treesitter/nvim-treesitter",
	main = "nvim-treesitter.configs",
	opts = {
		ensure_installed = { "lua", "markdown", "markdown_inline", "bash", "python", "fish" }, -- put the language you want in this array
		sync_install = false,
		highlight = {
			enable = true,       -- false will disable the whole extension
			disable = { "css" }, -- list of language that will be disabled
		},
		autopairs = {
			enable = true,
		},
		indent = { enable = true, disable = { "python", "css" } },

		context_commentstring = {
			enable = true,
			enable_autocmd = false,
		},
	},
	lazy = false,
	tag = "v0.10.0",
}
