return {
	cmd = { "vscode-json-language-server", "--stdio" },
	filetypes = { "json", "jsonc" },
	root_markers = { ".git" },
	settings = {
		json = {
			schemas = (function()
				local ok, ss = pcall(require, "schemastore")
				return ok and ss.json.schemas() or {}
			end)(),
			validate = { enable = true },
		},
	},
}
