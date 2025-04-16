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
	indent = { enable = true },
	sync_install = false,
	auto_install = true,
    matchup = {
        enable = true
    }
})
