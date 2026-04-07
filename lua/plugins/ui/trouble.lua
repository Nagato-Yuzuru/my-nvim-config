return {
	"folke/trouble.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		position = "bottom", -- 面板位置：bottom, top, left, right
		height = 10,
		mode = "workspace_diagnostics", -- 默认模式
		win = {
			wo = {
				wrap = true,
			},
		},
	},
	keys = {
		{
			"<leader>vP",
			"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
			desc = "Buffer Diagnostics (Trouble)",
		},
		-- 4. 查看 LSP 的引用列表 (替代原本的 gr 列表)
		{
			"gr",
			"<cmd>Trouble lsp_references toggle<cr>",
			desc = "LSP References (Trouble)",
		},
	},
}
