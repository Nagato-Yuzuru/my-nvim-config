return {
	cmd = { "ruff", "server" },
	filetypes = { "python" },
	-- root_dir 由 tools/lsp_root.lua 统一注入（它是所有非 SKIP server 的唯一
	-- 所有者，见该文件头部契约）——这里手写 root_dir 是死代码，故不写。
	root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
	init_options = {
		settings = {
			organizeImports = true,
		},
	},
}
