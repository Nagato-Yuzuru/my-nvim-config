return {
	cmd = { "gopls" },
	filetypes = { "go", "gomod", "gowork", "gotmpl" },
	root_markers = { "go.work", "go.mod", ".git" },
	settings = {
		gopls = {
			usePlaceholders = true,
			completeUnimported = true,
			analyses = { unusedparams = true, unreachable = true },
			experimentalStandaloneFiles = true,
		},
	},
}
