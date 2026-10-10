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
	-- :PyVersion 的 session 级版本覆盖，见 tools/python_version.lua。
	before_init = function(params, config) require("tools.python_version").ruff_before_init(params, config) end,
}
