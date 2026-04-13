return {
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		opts = {
			picker = {
				enabled = true,
				-- Replace vim.ui.select with Snacks' picker system-wide.
				-- Auto-benefits any plugin that prompts via vim.ui.select
				-- (e.g. LintaoAmons/bookmarks.nvim's list/delete prompts).
				ui_select = true,
				layout = { preset = "default" },
				sources = {
					explorer = {
						win = {
							list = {
								keys = {
									["]c"] = "explorer_git_next",
									["[c"] = "explorer_git_prev",
								},
							},
						},
					},
				},
			},
			explorer = {
				enabled = true,
				replace_netrw = true, -- hijack directory opens (was Neo-tree hijack_netrw)
			},
			dashboard = { enabled = true }, -- 启动页
		},
		keys = {
			{
				"<leader>vp",
				function()
					Snacks.explorer()
				end,
				desc = "Explorer",
			},
			{
				"<leader>,",
				function()
					Snacks.picker.buffers()
				end,
				desc = "Buffers",
			},
			{
				"<leader>/",
				function()
					Snacks.picker.grep()
				end,
				desc = "Grep",
			},
			{
				"<localleader>G",
				function()
					Snacks.lazygit()
				end,
				desc = "Git: Lazygit",
			},
			{
				"<localleader>gl",
				function()
					Snacks.lazygit.log()
				end,
				desc = "Git: Log (Lazygit)",
			},
		},
	},
}
