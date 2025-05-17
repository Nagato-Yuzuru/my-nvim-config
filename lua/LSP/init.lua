-- ./init.lua 或 Lazynvim 主配置文件
-- ~/.config/nvim/lua/LSP/init.lua
local lspconfig = require("lspconfig")
--local cmp_nvim_lsp = require("cmp_nvim_lsp")

local capabilities = vim.lsp.protocol.make_client_capabilities()

-- 通用 on_attach 函数，包含常用快捷键和诊断配置
local on_attach = function(client, bufnr)
	-- 诊断符号
	-- 新的、推荐的方式
	-- vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
	vim.diagnostic.config({
		float = { border = "rounded" },

		-- 使用官方文档推荐的 signs 结构
		signs = {
			-- 定义文本图标，使用 vim.diagnostic.severity 作为键
			text = {
				[vim.diagnostic.severity.ERROR] = "", -- 错误图标 (加空格)
				[vim.diagnostic.severity.WARN] = "", -- 警告图标 (加空格)
				[vim.diagnostic.severity.INFO] = "", -- 信息图标 (加空格)
				[vim.diagnostic.severity.HINT] = "💡", -- 提示图标 (使用简单的灯泡图标，加空格)
			},
			-- 定义数字列 (行号旁) 的高亮组
			numhl = {
				[vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
				[vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
				[vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
				[vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
			},
		},
	})
	-- 快捷键映射
	local bufopts = { noremap = true, silent = true, buffer = bufnr }
	vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts)
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
	vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
	vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
	vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, bufopts) -- 更改为 Ctrl+k 避免与默认行为冲突
	vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, bufopts)
	vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, bufopts)
	vim.keymap.set("n", "<space>wl", function()
		print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
	end, bufopts)
	vim.keymap.set("n", "<space>D", vim.lsp.buf.type_definition, bufopts)
	vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, bufopts)
	vim.keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, bufopts) -- 在 normal 和 visual 模式下
	vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)
	vim.keymap.set("n", "<space>f", function()
		vim.lsp.buf.format({ async = true })
	end, bufopts) -- 格式化

	vim.keymap.set("n", "[d", function()
		vim.diagnostic.jump({ count = -1, float = true })
	end, bufopts)
	vim.keymap.set("n", "]d", function()
		vim.diagnostic.jump({ count = 1, float = true })
	end, bufopts)
	vim.keymap.set("n", "<space>e", vim.diagnostic.open_float, bufopts) -- 显示行诊断信息
	vim.keymap.set("n", "<space>q", vim.diagnostic.setloclist, bufopts) -- 将诊断信息放入 location list

	-- (可选) 根据服务器能力设置保存时自动格式化
	-- if client.supports_method("textDocument/formatting") then
	--   vim.api.nvim_create_autocmd("BufWritePre", {
	--     group = vim.api.nvim_create_augroup("LspFormatOnSave_"..bufnr, { clear = true }),
	--     buffer = bufnr,
	--     callback = function() vim.lsp.buf.format({ bufnr = bufnr, timeout_ms = 500 }) end -- 设置超时避免卡顿
	--   })
	-- end
end

require("LSP.ruff")

-- (可选) 添加 schemastore.nvim 插件依赖 (如果使用 JSON/YAML schemas)
-- 在 init.lua 的 lazy.setup 中添加: { "b0o/schemastore.nvim" }

-- 配置诊断信息的显示样式
-- 使用 mason-lspconfig 来获取已安装的服务器并自动设置
vim.diagnostic.config({
	virtual_text = true, -- 在行尾显示诊断信息（简洁）
	signs = true,
	underline = true,
	update_in_insert = false, -- 插入模式下不更新诊断，提升性能
	severity_sort = true,
})

-- -- 更改诊断浮动窗口边框
-- local handlers = {
--     ["textDocument/hover"] = vim.lsp.with(vim.lsp.buf.signature_help, { border = "rounded" }),
--     ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.buf.signature_help, { border = "rounded" }),
-- }
-- for name, handler in pairs(handlers) do
--     vim.lsp.handlers[name] = handler
-- end
