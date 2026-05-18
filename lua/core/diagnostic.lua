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
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "",
			[vim.diagnostic.severity.WARN] = "",
			[vim.diagnostic.severity.INFO] = "",
			[vim.diagnostic.severity.HINT] = "",
		},
	},
	float = {
		border = "rounded",
		source = "if_many",
		header = "",
		prefix = "",
	},
})

-- ── ][d/D 跳转 + 自动浮窗 ──────────────────────────────────────────────
-- Neovim 0.11+ 默认绑定 ]d/[d/]D/[D 走 vim.diagnostic.jump，但**不传**
-- float = true，所以光跳光标、不显示诊断信息。覆盖默认让每次跳完顺便弹
-- 浮窗——避免还要再按 <C-w>d 看一眼。

-- 不用 jump({float=true})——它内部调 open_float 时传的 float_opts 与
-- <C-w>d 默认调用不完全一致 (scope/focus_id)，导致跳完后再按 <C-w>d
-- 不把已存在的浮窗识别为同一个，于是"打开新的、不聚焦"，要按两次。
-- 这里手动两步：先 jump（float=false），再用与 <C-w>d 完全相同的
-- open_float() 默认参数开浮窗，从而保证后续 <C-w>d 一次进入。
--
-- open_float 必须包 vim.schedule：jump 内部 nvim_win_set_cursor 触发的
-- CursorMoved 是异步派发的，如果同步调 open_float()，会先注册"CursorMoved
-- 关浮窗" autocmd，紧接着排队的 CursorMoved 立即把浮窗关掉，肉眼看不见。
--
-- focus=false 关键：open_floating_preview 在 focus=true(默认) 且发现已存在
-- 同 focus_id 的浮窗时会走 `wincmd p` 提前 return，不重算诊断内容——结果
-- 连续 ]d 时，前一次的浮窗还没被 CursorMoved 关掉，第二次就被"复用旧窗"
-- 短路掉了，新行的诊断弹不出来。focus=false 跳过该分支强制建新窗；window
-- var (focus_id="line") 仍会写上，所以后续 <C-w>d (默认 focus=true) 照旧
-- 能识别并聚焦。
local function jump(opts)
	return function()
		vim.diagnostic.jump(opts)
		vim.schedule(function()
			vim.diagnostic.open_float({ focus = false })
		end)
	end
end

vim.keymap.set("n", "]d", jump({ count = 1, float = false }), { desc = "Next diagnostic + float" })
vim.keymap.set("n", "[d", jump({ count = -1, float = false }), { desc = "Prev diagnostic + float" })
vim.keymap.set("n", "]D", jump({ count = math.huge, float = false, wrap = false }), { desc = "Last diagnostic + float" })
vim.keymap.set("n", "[D", jump({ count = -math.huge, float = false, wrap = false }), { desc = "First diagnostic + float" })
