-- ~/.config/nvim/lua/plugins/mason.lua
return function()
	require("mason").setup({
		ui = {
			border = "rounded",
			icons = {
				package_installed = "✓",
				package_pending = "➜",
				package_uninstalled = "✗",
			},
		},
	})

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
		start_delay = 3000,
		debounce_hours = 12,
	})
	vim.env.PATH = vim.env.PATH .. ":" .. vim.fn.stdpath("data") .. "/mason/bin"
end
