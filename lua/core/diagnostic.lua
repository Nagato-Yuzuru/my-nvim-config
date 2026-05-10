-- 诊断子系统设置（独立于 LSP）。
--
-- 为什么不塞进 core/lsp.lua：诊断在 nvim 里是独立子系统——不只 LSP 来源，
-- linter (nvim-lint)、formatter 错误、treesitter 解析错误也都走
-- vim.diagnostic。把诊断键位 / 配置放进 lsp.lua 会让"诊断 = LSP"这个误解
-- 固化。本文件作为后续诊断显示设置（vim.diagnostic.config）、toggle 等
-- 的统一归宿。
--
-- ── 当前内容：][d/D 跳转 + 自动浮窗 ─────────────────────────────────────
-- Neovim 0.11+ 默认绑定 ]d/[d/]D/[D 走 vim.diagnostic.jump，但**不传**
-- float = true，所以光跳光标、不显示诊断信息。覆盖默认让每次跳完顺便弹
-- 浮窗——避免还要再按 <C-w>d 看一眼。

local function jump(opts)
	return function()
		vim.diagnostic.jump(opts)
	end
end

vim.keymap.set("n", "]d", jump({ count = 1, float = true }), { desc = "Next diagnostic + float" })
vim.keymap.set("n", "[d", jump({ count = -1, float = true }), { desc = "Prev diagnostic + float" })
vim.keymap.set("n", "]D", jump({ count = math.huge, float = true, wrap = false }), { desc = "Last diagnostic + float" })
vim.keymap.set("n", "[D", jump({ count = -math.huge, float = true, wrap = false }), { desc = "First diagnostic + float" })
