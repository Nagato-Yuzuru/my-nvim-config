return {
	cmd = { "taplo", "lsp", "stdio" },
	filetypes = { "toml" },
	root_markers = { ".git" },
	settings = {
		taplo = {
			schema = {
				enable = true,
				repositoryEnable = true,
			},
			formatting = {
				alignEntries = true,
				alignComments = true,
				arrayTrailingComma = true,
				arrayAutoExpand = true,
				compactArrays = true,
				compactInlineTables = true,
			},
		},
	},
}
