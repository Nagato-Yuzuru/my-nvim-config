return {
	"stevearc/aerial.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	opts = {
		backends = { "treesitter", "lsp", "markdown", "asciidoc", "man" },
		layout = {
			min_width = 30,
			default_direction = "right",
		},
		show_guides = true,
		filter_kind = false,
	},
	cmd = { "AerialToggle", "AerialOpen", "AerialClose", "AerialNavToggle" },
	keys = {
		{
			"<leader>ns",
			function()
				require("aerial").snacks_picker()
			end,
			desc = "Structure (Picker)",
		},
		{
			"<leader>nS",
			"<cmd>AerialToggle!<cr>",
			desc = "Structure (Sidebar)",
		},
	},
}
