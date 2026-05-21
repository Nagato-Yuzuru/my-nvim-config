-- TypeSpec 语言服务器。二进制来自 `@typespec/compiler`（全局 npm 安装），
-- 不走 mason —— 因此本 server 不在 tools/mason_ensure.lua 的 LSP_TOOLS 里，
-- 由 core/lsp.lua 单独 vim.lsp.enable("tsp_server") 启动（同 `ty` 的处理）。
return {
	cmd = { "tsp-server", "--stdio" },
	filetypes = { "typespec" },
	-- tspconfig.yaml 是 TypeSpec 项目根的权威标记；package.json 兜底 monorepo /
	-- 子目录布局，.git 兜底脱离 npm 体系的纯库目录。
	root_markers = { "tspconfig.yaml", "package.json", ".git" },
}
