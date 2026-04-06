return {
	cmd = { "ty", "server" },
	filetypes = { "python" },
	root_markers = { "pyproject.toml", "ty.toml", ".git" },
	root_dir = function(bufnr, on_dir)
		local bufname = vim.api.nvim_buf_get_name(bufnr)
		if bufname == "" then
			on_dir(vim.uv.cwd())
			return
		end
		local root = vim.fs.root(bufnr, { "pyproject.toml", "ty.toml", ".git" })
		on_dir(root or vim.fs.dirname(bufname))
	end,
}
