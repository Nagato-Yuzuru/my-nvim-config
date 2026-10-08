return {
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
	root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
	settings = {
		-- Settings that must hold for every lua_ls client, including ones
		-- outside nvim, live in the repo's .luarc.json: runtime version and
		-- the `vim` / `Snacks` globals whitelist. Their types come from
		-- lazydev.nvim (plugins/lsp/lazydev.lua), nvim-only. .luarc.json
		-- overrides client settings key by key, so it must never set
		-- workspace.library: that would clobber lazydev's injected list.
		Lua = {
			workspace = { checkThirdParty = false },
		},
	},
}
