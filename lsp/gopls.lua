return {
	cmd = { "gopls" },
	filetypes = { "go", "gomod", "gowork", "gotmpl" },
	root_markers = { "go.work", "go.mod", ".git" },
	settings = {
		gopls = {
			usePlaceholders = true,
			completeUnimported = true,
			gofumpt = true,
			-- unusedparams/unreachable 由 golangci-lint 覆盖
			analyses = { unusedvariable = true },
			experimentalStandaloneFiles = true,
		},
	},
}
