return {
	"folke/todo-comments.nvim",
	event = { "BufReadPost", "BufNewFile" },
	dependencies = { "nvim-lua/plenary.nvim" },
	opts = {
		signs = true, -- 在行号栏显示图标
		sign_priority = 8,
		merge_keywords = true,
		keywords = {
			FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
			TODO = { icon = " ", color = "info" },
			HACK = { icon = " ", color = "warning" },
			WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
			PERF = { icon = " ", color = "hint", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
			NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
			TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
		},
		highlight = {
			multiline = true, -- 跨行
			before = "", -- 只高亮关键词及之后内容
			keyword = "fg", -- 关键词整词高亮
			after = "fg",
			pattern = [[.*<(KEYWORDS)\s*:?]], -- 形如 TODO: / FIXME:
			comments_only = true, --  只在“注释”里识别（依赖 treesitter）
			max_line_len = 400,
			exclude = {}, -- 可排除 filetype，比如 "markdown"
		},
		colors = {
			error = { "DiagnosticError", "ErrorMsg", "#DC2626" },
			warning = { "DiagnosticWarn", "WarningMsg", "#FBBF24" },
			info = { "DiagnosticInfo", "#2563EB" },
			hint = { "DiagnosticHint", "#10B981" },
			test = { "DiagnosticInfo", "#A78BFA" },
		},
		search = {
			command = "rg",
			args = {
				"--color=never",
				"--no-heading",
				"--with-filename",
				"--line-number",
				"--column",
				"--ignore-case",
			},
			pattern = [[\b(KEYWORDS)\s*:]], -- ripgrep 正则；匹配 TODO: / FIXME:
		},
	},
	keys = {
		{
			"]t",
			function()
				require("todo-comments").jump_next()
			end,
			desc = "Next TODO",
		},
		{
			"[t",
			function()
				require("todo-comments").jump_prev()
			end,
			desc = "Prev TODO",
		},
		-- 需要 Telescope 列表的话再装 telescope.nvim，然后开这个：
		--{ "<leader>tt", "<cmd>TodoTelescope<cr>",                            desc = "List TODOs (Telescope)" },
	},
}
