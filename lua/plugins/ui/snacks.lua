return {
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		opts = {
			-- Friendly help popup: rounded centered float with a title, instead of
			-- the default dense grid docked at the bottom.
			styles = {
				help = {
					position = "float",
					backdrop = false,
					border = "rounded",
					title = " Keymaps — press ? to close ",
					title_pos = "center",
					row = 0.15,
					col = 0.5,
					width = 0.6,
				},
			},
			picker = {
				enabled = true,
				-- Replace vim.ui.select with Snacks' picker system-wide.
				-- Auto-benefits any plugin that prompts via vim.ui.select
				-- (e.g. LintaoAmons/bookmarks.nvim's list/delete prompts).
				ui_select = true,
				layout = { preset = "default" },
				-- Wider columns → fewer keys per row, each entry gets breathing room.
				actions = {
					toggle_help_input = function(p)
						p.input.win:toggle_help({ col_width = 45, key_width = 14 })
					end,
					toggle_help_list = function(p)
						p.list.win:toggle_help({ col_width = 45, key_width = 14 })
					end,
				},
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
				"<leader>ss",
				function()
					Snacks.picker.lsp_workspace_symbols()
				end,
				desc = "Workspace Symbols",
			},
			{
				"<leader>sc",
				function()
					Snacks.picker.commands()
				end,
				desc = "Commands",
			},
			{
				"<leader>sk",
				function()
					Snacks.picker.keymaps()
				end,
				desc = "Keymaps",
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
