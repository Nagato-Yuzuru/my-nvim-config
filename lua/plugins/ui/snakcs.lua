return {
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		opts = {
			picker = {
				enabled = true,
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
