require("nvim-treesitter.configs").setup({
	ensure_installed = {
		"python",
		"go",
		"html",
		"json",
		"yaml",
		"bash",
		"sql",
		"c",
		"cpp",
		"lua",
		"toml",
		"rst",
		-- "gitcommit",
		-- "gitconfig",
		-- "gitignore",
	},
	highlight = {
		enable = true,
		additional_vim_regex_highlighting = false,
	},
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "gnn",
			node_incremental = "grna",
			scope_incremental = "grc",
			node_decremental = "grm",
		},
	},
	indent = { enable = true },
	sync_install = false,
	auto_install = true,
	matchup = {
		enable = true,
	},
})
