-- typos-lsp（tekumara/typos-lsp，crate-ci/typos 的 LSP 封装）：代码感知拼写检查，
-- 拆 camelCase/snake_case 后比对"已知拼错"清单——误报近零，但不识字典外的错词。
-- 修正走 <leader>ca。不设 filetypes = 全 ft 挂载（拼写不分语言）。
-- 项目级词表/排除写在 typos.toml / _typos.toml / .typos.toml（从 workspace 向上查找），
-- 改完需 :lsp restart。
return {
	cmd = { "typos-lsp" },
	root_markers = { "typos.toml", "_typos.toml", ".typos.toml", ".git" },
}
