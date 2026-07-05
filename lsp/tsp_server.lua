-- TypeSpec 语言服务器（tsp-server，随 `@typespec/compiler` 全局 npm 安装）。
-- 在 tools/mason_ensure.lua 的 LSP_TOOLS 里登记（bin "tsp-server" / mason
-- "tsp-server"），按常规 PATH-first / mason-fallback 处理：PATH 上有全局
-- @typespec/compiler 的 tsp-server 就用它，否则 mason 兜底装。由 core/lsp.lua
-- 的 vim.lsp.enable(native_servers) 统一启用（同 `ty` 的处理）。
return {
	cmd = { "tsp-server", "--stdio" },
	filetypes = { "typespec" },
	-- tspconfig.yaml 是 TypeSpec 项目根的权威标记；package.json 兜底 monorepo /
	-- 子目录布局，.git 兜底脱离 npm 体系的纯库目录。
	root_markers = { "tspconfig.yaml", "package.json", ".git" },
}
