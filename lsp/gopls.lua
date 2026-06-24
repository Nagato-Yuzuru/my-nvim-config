return {
	cmd = { "gopls" },
	filetypes = { "go", "gomod", "gowork", "gotmpl" },
	root_markers = { "go.work", "go.mod", ".git" },
	settings = {
		gopls = {
			usePlaceholders = true,
			-- 只对**限定前缀**生效（`strings.Bui` → 补全 + 自动 import）；它**不**做裸标识符
			-- 未导入补全（裸 `Builder` → `strings.Builder`）——那是 gopls 固有缺口 golang/go#58291。
			-- IDEA 风的裸标识符自动 import 由 go-deep.nvim 补足，见
			-- lua/plugins/completion/go_deep.lua。别因为这行就以为裸标识符已覆盖。
			completeUnimported = true,
			-- 风格规整（gofumpt / gci / golines / import 分组）统一交给
			-- `golangci-lint fmt`，按仓库 `.golangci.yml` 的 formatters 块跑；
			-- 这里不再开 `gofumpt = true`，避免 `vim.lsp.buf.format()` 路径绕过
			-- conform 的 picker 强加 gofumpt 规则、与仓库声明产生分歧。
			-- 详见 lua/plugins/format/conform.lua 的 pick_go_formatter。
			-- unusedparams/unreachable 由 golangci-lint 覆盖
			analyses = { unusedvariable = true },
			experimentalStandaloneFiles = true,
			-- IDEA-style inline hints。全局开关由 core/lsp.lua 的
			-- vim.lsp.inlay_hint.enable(true) 控制；这里只决定 gopls 上报哪些类别。
			hints = {
				assignVariableTypes = true,
				compositeLiteralFields = true,
				compositeLiteralTypes = true,
				constantValues = true,
				functionTypeParameters = true,
				parameterNames = true,
				rangeVariableTypes = true,
			},
		},
	},
}
