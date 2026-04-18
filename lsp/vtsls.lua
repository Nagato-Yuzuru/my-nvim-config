-- vtsls: VSCode TypeScript Language Server 的 LSP 包装
-- 与 denols 通过 root_dir 互斥：若 buffer 落在 deno 项目内，vtsls 不挂载
local DENO_MARKERS = { "deno.json", "deno.jsonc", "deno.lock" }
local NODE_MARKERS = { "tsconfig.json", "jsconfig.json", "package.json" }

return {
	cmd = { "vtsls", "--stdio" },
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	root_markers = NODE_MARKERS,
	root_dir = function(bufnr, on_dir)
		local deno_root = vim.fs.root(bufnr, DENO_MARKERS)
		local node_root = vim.fs.root(bufnr, NODE_MARKERS)
		-- deno 更深（更近）或同级 → 让位给 denols
		if deno_root and (not node_root or #deno_root >= #node_root) then
			return
		end
		if node_root then on_dir(node_root) end
	end,
	settings = {
		typescript = {
			inlayHints = {
				parameterNames = { enabled = "literals" },
				parameterTypes = { enabled = true },
				variableTypes = { enabled = false },
				propertyDeclarationTypes = { enabled = true },
				functionLikeReturnTypes = { enabled = true },
				enumMemberValues = { enabled = true },
			},
			updateImportsOnFileMove = { enabled = "always" },
			suggest = { completeFunctionCalls = true },
		},
		javascript = {
			inlayHints = {
				parameterNames = { enabled = "literals" },
				parameterTypes = { enabled = true },
				variableTypes = { enabled = false },
				propertyDeclarationTypes = { enabled = true },
				functionLikeReturnTypes = { enabled = true },
				enumMemberValues = { enabled = true },
			},
			updateImportsOnFileMove = { enabled = "always" },
		},
		vtsls = {
			experimental = {
				completion = { enableServerSideFuzzyMatch = true },
			},
		},
	},
}
