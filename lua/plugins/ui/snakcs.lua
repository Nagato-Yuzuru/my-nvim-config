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
			},
			explorer = { enabled = false }, -- 替代 NeoTree/NvimTree
			dashboard = { enabled = true }, -- 启动页
		},
		-- 这是一个自动按键映射的示例，按需添加
		keys = {
			-- {
			-- 	"<leader><space>",
			-- 	function()
			-- 		Snacks.picker.smart()
			-- 	end,
			-- 	desc = "Smart Find Files",
			-- },
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
		},
	},
}
