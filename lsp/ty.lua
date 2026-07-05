return {
	cmd = { "ty", "server" },
	filetypes = { "python" },
	-- root_dir 由 tools/lsp_root.lua 统一注入（唯一所有者，见该文件头部契约）。
	-- 无名 scratch python buffer 也做类型检查、落到 cwd 当 root，见该文件的
	-- UNNAMED_CWD={ty=true}——这里手写 root_dir 是死代码，故不写。
	root_markers = { "pyproject.toml", "ty.toml", ".git" },
}
