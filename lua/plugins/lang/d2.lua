return {
	"ravsii/tree-sitter-d2",
	ft = { "d2" },
	version = "*",
	build = "make nvim-install",
	-- grammar-only 仓库不带 ftdetect，nvim 默认不会把 .d2 识别成 ft=d2，
	-- 进而 ft 触发器永远不点火。这里手动登记。
	init = function() vim.filetype.add({ extension = { d2 = "d2" } }) end,
}
