return {
	"folke/trouble.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		focus = true,
		follow = false, -- 不自动跟随光标跳转，需手动确认（<cr> / l）
		auto_preview = true, -- 光标移动时自动显示浮窗预览
		preview = {
			type = "float",
			relative = "editor",
			border = "rounded",
			title = "Preview",
			size = { width = 0.7, height = 0.4 },
			position = { 0.5, 0.5 },
		},
		win = {
			position = "bottom",
			height = 10,
			wo = {
				wrap = true,
			},
		},
	},
	keys = {
		{
			"<leader>vP",
			"<cmd>Trouble diagnostics toggle filter.buf=0 focus=false<cr>",
			desc = "Buffer Diagnostics (Trouble)",
		},
		{
			"<leader>nu",
			"<cmd>Trouble lsp_references toggle<cr>",
			desc = "Find Usages (Trouble)",
		},
	},
}
