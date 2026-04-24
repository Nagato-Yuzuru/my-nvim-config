return {
	cmd = { "ruff", "server" },
	filetypes = { "python" },
	root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
	root_dir = function(bufnr, on_dir)
		local bufname = vim.api.nvim_buf_get_name(bufnr)
		-- ruff 要求 document 有真实文件路径
		if bufname == "" then
			return
		end
		local root = vim.fs.root(bufnr, { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" })
		on_dir(root or vim.fs.dirname(bufname))
	end,
	init_options = {
		settings = {
			organizeImports = true,
		},
	},
}
