return {
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
	root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
	settings = {
		Lua = {
			-- `Snacks` is a runtime global injected by snacks.nvim. Type
			-- definitions for it (and the snacks.* annotation namespace) are
			-- pulled in by lazydev.nvim (plugins/lsp/lazydev.lua); this entry
			-- only whitelists the global itself so it isn't flagged as
			-- undefined.
			diagnostics = { globals = { "vim", "Snacks" } },
			workspace = { checkThirdParty = false },
		},
	},
}
