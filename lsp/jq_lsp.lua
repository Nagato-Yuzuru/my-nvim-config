-- jq-lsp（wader/jq-lsp，Go 二进制，mason 包 jq-lsp）：诊断 / 补全 / hover 内置
-- 文档 / goto-def / include-import。ft 是 nvim 内置的 jq（*.jq），parser 在
-- plugins/treesitter.lua——语言面没有事实可注册，故无 plugins/lang/jq.lua
--（偏离"add a language"配方的唯一一步）。
-- .jq-lsp.jq 是 server 的自定义 builtins 声明文件，作 root marker 优先于 .git。
return {
	cmd = { "jq-lsp" },
	filetypes = { "jq" },
	root_markers = { ".jq-lsp.jq", ".git" },
}
