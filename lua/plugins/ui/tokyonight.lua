return {
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000, -- 先于其他 UI 加载
		opts = {
			style = "moon",
			transparent = false,
			styles = {
				sidebars = "normal",
				floats = "normal",
			},
			on_highlights = function(hl, c)
				hl.LineNr = { fg = "#dddddd" }
				hl.CursorLineNr = { fg = "#ff996c" }
				-- 诊断字符波浪线：tokyonight 默认就是 undercurl，但有些 colorscheme
				-- /组合下会被静默换成普通 underline。显式重申一遍，sp 沿用主题色——
				-- 支持 SGR 4:3 的终端（Ghostty）没 Smulx 能力也能还原成波浪。
				hl.DiagnosticUnderlineError = { undercurl = true, sp = c.error }
				hl.DiagnosticUnderlineWarn = { undercurl = true, sp = c.warning }
				hl.DiagnosticUnderlineInfo = { undercurl = true, sp = c.info }
				hl.DiagnosticUnderlineHint = { undercurl = true, sp = c.hint }
			end,
		},
		config = function(_, opts)
			require("tokyonight").setup(opts)
			vim.cmd.colorscheme("tokyonight")
		end,
	},
}
