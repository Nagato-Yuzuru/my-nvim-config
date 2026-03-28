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
		branch = "main",
		config = function()
			local status_ok, configs = pcall(require, "nvim-treesitter.config")

			if not status_ok then
				vim.notify("Treesitter uncompleted, skip...", vim.log.levels.WARN)
				return
			end
			configs.setup({
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
					"terraform",
				},
				highligh = { enable = true },
				auto_install = true,
			})
		end,
	},
}
