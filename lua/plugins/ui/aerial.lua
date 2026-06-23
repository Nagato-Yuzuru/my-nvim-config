return {
	"stevearc/aerial.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	opts = {
		-- aerial 的 backends 支持 per-filetype 覆写：`_` 是默认，其它 key 是 ft。
		-- JSON 特殊：treesitter 后端只把 "value 为 object 的 pair" 当作符号，
		-- 导致大纲只剩嵌套对象骨架，标量 / 数组下标都看不到。jsonls 的
		-- documentSymbol 更细（标量叶子、数组索引都有），更适合作导航目录。
		backends = {
			["_"] = { "treesitter", "lsp", "markdown", "asciidoc", "man" },
			json = { "lsp", "treesitter" },
			jsonc = { "lsp", "treesitter" },
		},
		layout = {
			min_width = 30,
			default_direction = "right",
		},
		show_guides = true,
		filter_kind = false,
	},
	cmd = { "AerialToggle", "AerialOpen", "AerialClose", "AerialNavToggle" },
	-- Two entry points, two namespaces:
	--   <leader>ns  transient picker  → mirrors IdeaVim FileStructurePopup
	--                                   (Navigation extras, no g* equivalent)
	--   <leader>vs  persistent sidebar → mirrors IdeaVim ActivateStructureToolWindow
	--                                   (Views namespace, tool-window semantics)
	keys = {
		{
			"<leader>ns",
			function() require("aerial").snacks_picker() end,
			desc = "Structure (Picker)",
		},
		{
			"<leader>vs",
			"<cmd>AerialToggle!<cr>",
			desc = "Structure (Sidebar)",
		},
	},
}
