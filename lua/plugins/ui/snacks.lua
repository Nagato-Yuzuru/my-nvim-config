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
			notifier = { enabled = true },
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
				"<leader>ns",
				function()
					Snacks.picker.lsp_symbols()
				end,
				desc = "Document Symbols",
			},
			{
				"<leader>nS",
				function()
					Snacks.picker.lsp_workspace_symbols()
				end,
				desc = "Workspace Symbols",
			},
			{
				"<leader>nC",
				function()
					Snacks.picker.commands()
				end,
				desc = "Commands",
			},
			{
				"<leader>vn",
				function()
					Snacks.notifier.show_history()
				end,
				desc = "Notification History",
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
