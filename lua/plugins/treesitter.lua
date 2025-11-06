return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		event = "BufReadPost",
		dependencies = {
			{
				import = "plugins.ft.d2",
			},
		},
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = {
					"lua",
					"python",
					"go",
					"json",
					"yaml",
					"bash",
					"markdown",
					"html",
					"javascript",
					"toml",
					"typescript",
					"markdown_inline",
					"html",
					"latex",
					"d2",
				},
				highligh = { enable = true },
			})
		end,
	},
}
