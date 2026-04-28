-- Typst LSP（tinymist）。语义补全 / 诊断 / 跳转 / 格式化全靠它。
-- formatterMode = typstyle 让 LSP 也能格式化；conform 同时显式登记 typstyle，
-- 与其它语言保持"formatter 走 conform，LSP 兜底"的一致约定。
--
-- exportPdf 默认 "never"——避免 :w 顺手在 worktree 里掉一个 .pdf。
-- WYSIWYG 由 plugins/lang/typst.lua 里的 typst-preview.nvim 接管，更精确也更
-- 可控。需要"保存即出 PDF"再改成 "onSave"。
return {
	cmd = { "tinymist" },
	filetypes = { "typst" },
	root_markers = { "typst.toml", ".git" },
	settings = {
		formatterMode = "typstyle",
		exportPdf = "never",
		semanticTokens = "enable",
	},
}
