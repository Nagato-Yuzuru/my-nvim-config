-- 语言域：Swift —— 只有 LSP enablement 探测（无插件）。
-- sourcekit-lsp 随 Swift 工具链来（Xcode CLT / swiftly），不是 Mason 包，不进
-- install plane 的 LSP_TOOLS。此机 /usr/bin/sourcekit-lsp 直接在 PATH；
-- executable("xcrun") 兜住仅 full-Xcode 工具链内可达的机器（lsp/sourcekit.lua 的
-- cmd 会相应回落到 `xcrun sourcekit-lsp`）。无 Swift 环境时不挂、不刷 client-quit。
-- swiftformat / swiftlint 由 mise 提供（why 见 mason_ensure.lua / nvim-lint.lua）；
-- codelldb 调试见 dap/、Swift Testing 见 runtime/neotest.lua。
require("tools.lang_registry").register("swift", {
	lsp = { sourcekit = { probe = { "sourcekit-lsp", "xcrun" } } },
})

return {}
