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
	-- 心智模型："Search 用 picker / View 用 panel"，所以两个键各管一边：
	--   <leader>st  → Snacks picker          搜关键词、快速跳一个
	--   <leader>vt  → Trouble panel (TodoTrouble = `Trouble todo` 的 alias)
	--                                        逐条走列表、面板保持打开
	-- todo-comments 同时提供两套源：
	--   Snacks 集成在 `lua/todo-comments/snacks.lua`（setup 时注册 source）
	--   Trouble 集成在 `lua/trouble/sources/todo.lua`（v3 source 协议）
	-- 都不需要额外配置；trouble.nvim 在 ui/trouble.lua 加了 cmd = "Trouble"，
	-- 所以 :TodoTrouble 触发的 :Trouble todo 也能 lazy-load 起来。
	keys = {
		{
			"]t",
			function() require("todo-comments").jump_next() end,
			desc = "Next TODO",
		},
		{
			"[t",
			function() require("todo-comments").jump_prev() end,
			desc = "Prev TODO",
		},
		{
			"<leader>st",
			function() Snacks.picker.todo_comments() end,
			desc = "Search TODOs (picker)",
		},
		{
			"<leader>vt",
			"<cmd>TodoTrouble<cr>",
			desc = "TODOs (Trouble panel)",
		},
	},
}
