return {
	cmd = { "terraform-ls", "serve" },
	filetypes = { "terraform", "terraform-vars" },
	root_markers = { ".terraform", ".git" },
	init_options = {
		experimentalFeatures = {
			validateOnSave = true,
			prefillRequiredFields = true,
		},
	},
}
