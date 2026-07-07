-- In-process codeAction server:把 nvim-lint 塞进 diagnostic user_data 的
-- golangci-lint SuggestedFixes 暴露成标准 code action(<leader>ca / <A-CR>)。
-- 全链路见 lua/tools/golangci_fix.lua 顶部注释。无外部二进制,cmd 是进程内
-- 函数,attach 零成本。
return {
	cmd = require("tools.golangci_fix").server,
	filetypes = { "go" },
	root_markers = { "go.mod", ".git" },
}
