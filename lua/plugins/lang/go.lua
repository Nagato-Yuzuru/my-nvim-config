-- 语言域：Go —— ft 补充 + 进程内 golangci_fix server（无插件；go-deep.nvim 的
-- 补全接线归 completion 域，见 CLAUDE.md）。
-- gopls / goimports / golangci-lint 的安装归 install plane（mason_ensure.lua）。
require("tools.lang_registry").register("go", {
	ft = {
		extension = { gotmpl = "gotmpl" },
		filename = { ["go.work"] = "gowork" },
	},
	-- golangci_fix：进程内 codeAction server（lsp/golangci_fix.lua），把 nvim-lint
	-- 存进 diagnostic user_data 的 golangci SuggestedFixes 变成 <leader>ca / <A-CR>
	-- 可用的 quickfix。无外部二进制、无需探测（probe 省略 = 无条件 enable）。
	lsp = { golangci_fix = { in_process = true } },
})

return {}
