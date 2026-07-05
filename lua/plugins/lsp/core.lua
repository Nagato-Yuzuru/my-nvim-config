return {
	-- Mason: 工具安装器
	{
		"williamboman/mason.nvim",
		build = ":MasonUpdate",
		config = function()
			require("mason").setup()

			-- LSP 自动安装在 core/lsp.lua 的 setup() 里集中调度（和 capabilities
			-- 注入按显式顺序跑，不受 VeryLazy autocmd 注册顺序影响）。这里只负责
			-- formatter/linter 的 FileType 触发：FileType autocmd 必须在启动时就
			-- 注册好，否则首次打开对应文件不触发安装。
			vim.api.nvim_create_autocmd("FileType", {
				callback = function(ev) require("tools.mason_ensure").ensure_for_ft(vim.bo[ev.buf].filetype) end,
			})
		end,
	},

	-- SchemaStore（jsonls / yamlls 的 lsp/*.lua 中 require；:SchemaSelect picker
	-- 在 plugins/schemas/picker.lua 里也消费它）
	{ "b0o/SchemaStore.nvim", lazy = true },
}
