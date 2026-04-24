return {
	cmd = { "pyright-langserver", "--stdio" },
	filetypes = { "python" },
	root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "pyrightconfig.json", ".git" },
	root_dir = function(bufnr, on_dir)
		local bufname = vim.api.nvim_buf_get_name(bufnr)
		if bufname == "" then
			on_dir(vim.uv.cwd())
			return
		end
		local root = vim.fs.root(
			bufnr,
			{ "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "pyrightconfig.json", ".git" }
		)
		on_dir(root or vim.fs.dirname(bufname))
	end,
	settings = {
		python = {
			analysis = {
				typeCheckingMode = "basic",
			},
		},
	},
}
