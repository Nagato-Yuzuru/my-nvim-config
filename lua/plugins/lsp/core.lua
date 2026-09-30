return {
	-- Mason: 工具安装器
	{
		"williamboman/mason.nvim",
		build = ":MasonUpdate",
		config = function()
			-- append：运行时解析也 PATH 优先（默认 prepend 会让兜底装过的副本永久
			-- 遮蔽 mise/rustup 版本）。verify_cmd 识破的坏条目由覆盖目录单独路由回 mason。
			require("mason").setup({ PATH = "append" })
			require("tools.mason_ensure").setup_path()

			-- 日常档在 core/lsp.lua 的 VeryLazy hook 里装（和 capabilities 注入按显式
			-- 顺序跑）。这里只负责按需档的 FileType 触发（formatter/linter + 非日常
			-- LSP）：FileType autocmd 必须在启动时就注册好，否则首次打开对应文件不触发安装。
			vim.api.nvim_create_autocmd("FileType", {
				callback = function(ev) require("tools.mason_ensure").ensure_for_ft(vim.bo[ev.buf].filetype) end,
			})
		end,
	},

	-- SchemaStore（jsonls / yamlls 的 lsp/*.lua 中 require；:SchemaSelect picker
	-- 在 plugins/schemas/picker.lua 里也消费它）
	{ "b0o/SchemaStore.nvim", lazy = true },
}
