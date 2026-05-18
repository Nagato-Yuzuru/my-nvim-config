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
			-- IDEA-style inline hints。全局开关由 core/lsp.lua 的
			-- vim.lsp.inlay_hint.enable(true) 控制；这里只决定 gopls 上报哪些类别。
			hints = {
				assignVariableTypes = true,
				compositeLiteralFields = true,
				compositeLiteralTypes = true,
				constantValues = true,
				functionTypeParameters = true,
				parameterNames = true,
				rangeVariableTypes = true,
			},
		},
	},
}
