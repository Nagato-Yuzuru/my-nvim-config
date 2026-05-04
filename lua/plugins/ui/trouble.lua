return {
	"folke/trouble.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	-- 让任何 :Trouble * 调用都能触发 lazy-load —— 防止其它插件
	-- （如 todo-comments 的 :TodoTrouble 走 :Trouble todo）在 trouble
	-- 还没加载时撞 E492。keys 触发器只覆盖具体快捷键，不覆盖命令调用。
	cmd = "Trouble",
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
			"gr",
			"<cmd>Trouble lsp_references toggle<cr>",
			desc = "LSP References (Trouble)",
		},
	},
}
