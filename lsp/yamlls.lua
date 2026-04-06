return {
	cmd = { "yaml-language-server", "--stdio" },
	filetypes = { "yaml", "yaml.docker-compose" },
	root_markers = { ".git" },
	settings = {
		yaml = {
			keyOrdering = false,
			schemaStore = { enable = false, url = "" },
			schemas = (function()
				local ok, ss = pcall(require, "schemastore")
				return ok and ss.yaml.schemas() or {}
			end)(),
			validate = true,
			completion = true,
			hover = true,
		},
	},
}
