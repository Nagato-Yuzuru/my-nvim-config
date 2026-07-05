-- 注释全部走原生 gc / gcc / operator-pending gc（Neovim 0.10+，走 commentstring，
-- 见 runtime/lua/vim/_core/defaults.lua）。
--
-- ts-comments.nvim 只增强内置注释的 commentstring 解析：在 treesitter 嵌入上下文里
-- （如 lua 里的 vim.cmd[[...]]、html 里的 <script> / <style>、jsx 等）选对注释符。
-- 不接管任何按键，纯 opts = {}。
--
-- gb/gbc 块注释故意不提供：原生没有块注释等价物，唯一成熟实现 Comment.nvim
-- 长期无人维护（2024-08 后无合并、0.12 兼容 PR 未并），权衡后放弃块注释，
-- 不要重新引入。
--
-- Parity：.ideavimrc 侧 gc 走 set commentary，同样不提供块注释键位。
return {
	{
		"folke/ts-comments.nvim",
		event = "VeryLazy",
		enabled = vim.fn.has("nvim-0.10.0") == 1,
		opts = {},
	},
}
