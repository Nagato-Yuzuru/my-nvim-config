return {
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		opts = {
			-- 只开 cmdline，不接管其他消息
			cmdline = { enabled = true, view = "cmdline_popup" },
			messages = { enabled = false },
			notify = { enabled = false },
			popupmenu = { enabled = false },
			lsp = {
				progress = { enabled = false }, -- 不显示进度；lualine 只显示已 attach 的 server 名
				hover = { enabled = false }, -- 走 LSP 默认 K (vim.lsp.buf.hover)
				signature = { enabled = false }, -- blink 的签名窗
			},
			presets = {
				command_palette = true, -- 类 IDE 命令面板布局
				bottom_search = false,
			},
			views = {
				cmdline_popup = {
					position = { row = "17%", col = "50%" },
					size = { width = 60, height = "auto" },
					border = { style = "rounded", padding = { 1, 2 } },
					win_options = { winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder" },
				},
			},
		},
		dependencies = {
			"MunifTanjim/nui.nvim",
		},
	},
}
