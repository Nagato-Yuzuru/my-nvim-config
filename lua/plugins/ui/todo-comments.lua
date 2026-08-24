-- ]t/[t 环形跳转：上游 jump.lua 扫到缓冲区一端即停（无 wrap 选项），这里
-- 用同一套判定（highlight.match + comments_only/is_comment，逐行逻辑与上游
-- jump.lua 一致）重实现，模运算绕环。依赖插件内部 API——lazy-lock 钉版本，
-- :Lazy update 时复查签名。
local function jump_wrap(up)
	local tc_config = require("todo-comments.config")
	local tc_hl = require("todo-comments.highlight")
	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	local row = vim.api.nvim_win_get_cursor(win)[1]
	local total = vim.api.nvim_buf_line_count(buf)
	local step = up and -1 or 1
	for i = 1, total do
		local l = ((row - 1 + step * i) % total) + 1
		local line = vim.api.nvim_buf_get_lines(buf, l - 1, l, false)[1] or ""
		local ok, start = pcall(tc_hl.match, line)
		-- is_comment 返回 nil（无 treesitter parser）时放行，与上游同
		if
			ok
			and start
			and not (tc_config.options.highlight.comments_only and tc_hl.is_comment(buf, l - 1, start) == false)
		then
			vim.api.nvim_win_set_cursor(win, { l, start - 1 })
			return
		end
	end
	vim.notify("No todo comments in buffer", vim.log.levels.WARN)
end

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
			-- 形如 TAG: 或 TAG(scope):——(scope) 可选，记 owner/issue 上下文。
			-- 冒号必需。此 pattern 是三个面的唯一判定：buffer 高亮、]t/[t 跳转、
			-- search 复筛（search.lua 对每条 rg 结果再跑 highlight.match，且 \C
			-- 大小写敏感）。search 面没有 treesitter 上下文，冒号是“tag 而非
			-- 散文/代码（如 vim.log.levels.WARN）”的唯一信号——去掉冒号要求
			-- 会让高亮承诺 panel 兑现不了的东西。
			-- 组结构有约定：highlight.match 取 \1 当高亮跨度、\2 当关键词名，
			-- 所以 (scope) 段必须用 %( ) 非捕获组
			pattern = [[.*<((KEYWORDS)%(\(.{-1,}\))?)\s*:]],
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
				-- 不加 --ignore-case：最终过滤是 highlight.match（\C 敏感），
				-- rg 忽略大小写只会捞进必被复筛掉的行
			},
			pattern = [[\b(KEYWORDS)(\([^)]*\))?\s*:]], -- ripgrep 预过滤；与 highlight.pattern 同构
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
			function() jump_wrap(false) end,
			desc = "Next TODO",
		},
		{
			"[t",
			function() jump_wrap(true) end,
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
