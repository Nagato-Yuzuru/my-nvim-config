-- Racket LSP（racket-langserver）。SICP 主力实现 + Racket 项目本身的 LSP。
--
-- 安装：raco pkg install racket-langserver（需先装好 racket 本体；mason 不
-- 提供这个包，由 lua/tools/scheme_ensure.lua 在打开 .rkt 时探测并提示）。
--
-- 注意：racket-langserver 没有针对 #lang sicp 的特化设置——它直接走 racket
-- 解释器加载，所以 #lang 头是什么都能 hover/补全。
return {
	cmd = { "racket", "--lib", "racket-langserver" },
	filetypes = { "racket" },
	root_markers = { "info.rkt", "manifest.rktl", ".git" },
}
