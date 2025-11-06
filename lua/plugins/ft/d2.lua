return {
	"ravsii/tree-sitter-d2",
	ft = { "d2" },
	event = "VeryLazy",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	version = "*", -- use the latest git tag instead of main
	build = "make nvim-install",
}
