-- plugins/mason/installer.lua
print("--- Mason Tool Installer Setup Called ---") -- 添加这行

require("mason-tool-installer").setup({
	ensure_installed = {
		-- Lua
		"lua-language-server",
		"stylua",
		"luacheck",

		-- Python
		"pyright",
		"ruff",
		"debugpy",
		"mypy",

		-- YAML
		"yaml-language-server",
		"prettier",
		"yamllint",

		-- Go
		"gopls",
		"golangci-lint",
		"delve",
		"staticcheck",

		-- Shell
		"bash-language-server",
		"shfmt",
		"shellcheck",

		-- 其他（可选）
		"json-lsp",
		"clangd",
		"codelldb",
	},
	auto_update = false,
	run_on_start = true,
	start_delay = 300,
	debounce_hours = 12,
})

vim.schedule(function()
     vim.env.PATH = vim.env.PATH .. ":" .. vim.fn.stdpath("data") .. "/mason/bin"
 end)
