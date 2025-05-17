vim.lsp.config("ruff", {
	init_options = {
		settings = {
			args = {
				"--fix",
			},
		},
	},
})

vim.lsp.enable("ruff")
