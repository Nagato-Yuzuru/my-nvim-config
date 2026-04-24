return {
	cmd = { "deno", "lsp" },
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	root_markers = { "deno.json", "deno.jsonc", "deno.lock" },
	root_dir = function(bufnr, on_dir)
		local root = vim.fs.root(bufnr, { "deno.json", "deno.jsonc", "deno.lock" })
		if root then
			on_dir(root)
		end
	end,
	settings = {
		deno = {
			enable = true,
			lint = true,
			unstable = false,
			suggest = {
				imports = {
					hosts = {
						["https://deno.land"] = true,
						["https://jsr.io"] = true,
					},
				},
			},
			inlayHints = {
				parameterNames = { enabled = "literals" },
				parameterTypes = { enabled = true },
				variableTypes = { enabled = false },
				propertyDeclarationTypes = { enabled = true },
				functionLikeReturnTypes = { enabled = true },
				enumMemberValues = { enabled = true },
			},
		},
	},
}
