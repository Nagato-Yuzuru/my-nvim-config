-- eslint-lsp: 项目有 ESLint 配置时提供诊断 + source.fixAll.eslint code action
-- Deno 项目跳过（denols 内置 deno lint）
local DENO_MARKERS = { "deno.json", "deno.jsonc", "deno.lock" }
local ESLINT_MARKERS = {
	"eslint.config.js", "eslint.config.mjs", "eslint.config.cjs", "eslint.config.ts",
	".eslintrc", ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.mjs",
	".eslintrc.yaml", ".eslintrc.yml", ".eslintrc.json",
	"package.json",
}

return {
	cmd = { "vscode-eslint-language-server", "--stdio" },
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	root_markers = ESLINT_MARKERS,
	root_dir = function(bufnr, on_dir)
		if vim.fs.root(bufnr, DENO_MARKERS) then return end
		local root = vim.fs.root(bufnr, ESLINT_MARKERS)
		if root then on_dir(root) end
	end,
	settings = {
		workingDirectories = { mode = "auto" },
		format = false,
	},
}
