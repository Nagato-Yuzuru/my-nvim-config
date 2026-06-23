-- 诊断子系统设置（独立于 LSP）。
--
-- 为什么不塞进 core/lsp.lua：诊断在 nvim 里是独立子系统——不只 LSP 来源，
-- linter (nvim-lint)、formatter 错误、treesitter 解析错误也都走
-- vim.diagnostic。把诊断键位 / 配置放进 lsp.lua 会让"诊断 = LSP"这个误解
-- 固化。本文件作为后续诊断显示设置（vim.diagnostic.config）、toggle 等
-- 的统一归宿。
--
-- ── 显示策略 ───────────────────────────────────────────────────────────
-- IDEA / Error Lens 风：行内胶囊显示消息，字符级波浪线指字符位置。
--   · underline       : 字符范围波浪线（LSP/linter 的 range 本就字符级）
--   · signs           : 行首图标——多源时按 severity 排
--   · virtual_text    : 关——由 plugins/ui/tiny-inline-diagnostic.lua 接管
--                       （彩色圆角胶囊；远处行截断 + 光标行展开全部诊断）
--   · virtual_lines   : 关——tiny-inline 的 show_all_diags_on_cursorline
--                       已经覆盖了"光标行展开多行"这个需求
--   · severity_sort   : 同一处多条诊断时 error 排最前
--   · update_in_insert: 关闭——插入时频繁刷诊断会卡 + 视觉跳动
-- 终端必须支持 undercurl 才看得到波浪线（WezTerm/Kitty/Ghostty/iTerm2 新版
-- 都支持；老 Terminal.app 没有，会回落成普通下划线）。
vim.diagnostic.config({
	underline = true,
	severity_sort = true,
	update_in_insert = false,
	virtual_text = false,
	virtual_lines = false,
	-- Sign icons：用 \u{} 转义直接落 Nerd Font codepoint，避免图标在文件 IO /
	-- 工具传递时被悄悄吃掉。这四个都在 Nerd Font Codicons 区段 (U+EA60-EAFF)，
	-- 任何 Nerd Font Symbols 包都有。
	-- 想换其它图标参考 https://www.nerdfonts.com/cheat-sheet，挑好后填 U+xxxx。
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "\u{EA87}", --  error
			[vim.diagnostic.severity.WARN] = "\u{EA6C}", --  warning
			[vim.diagnostic.severity.INFO] = "\u{EA74}", --  info
			[vim.diagnostic.severity.HINT] = "\u{EA61}", --  lightbulb
		},
	},
	float = {
		border = "rounded",
		source = "if_many",
		header = "",
		prefix = "",
	},
})

-- ── ][d/D 跳转 ─────────────────────────────────────────────────────────
-- Neovim 0.11+ 默认绑定 ]d/[d/]D/[D 走 vim.diagnostic.jump。这里只显式
-- 列出 ]D/[D（首末跳）来覆盖默认——]d/[d 默认行为已经够用，但保留同名
-- 绑定方便后面想替换源（如改成 trouble.nvim 的 next/prev）。
--
-- 不再附带浮窗：tiny-inline-diagnostic 的 show_diags_only_under_cursor
-- 模式下，跳到诊断行后气泡自动出现，等价于"自动 open_float"但不抢焦点、
-- 不需要 schedule 兜 CursorMoved。需要看 diagnostic code / related info
-- 时手动按 <C-w>d（Neovim 0.11+ 默认绑定）打传统浮窗。
vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Prev diagnostic" })
vim.keymap.set(
	"n",
	"]D",
	function() vim.diagnostic.jump({ count = math.huge, wrap = false }) end,
	{ desc = "Last diagnostic" }
)
vim.keymap.set(
	"n",
	"[D",
	function() vim.diagnostic.jump({ count = -math.huge, wrap = false }) end,
	{ desc = "First diagnostic" }
)
