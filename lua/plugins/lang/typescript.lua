-- 语言域：TypeScript / JavaScript —— 原生 TS LSP（lsp/tsc.lua）的 enablement 探测
--（无插件）。稳定通道二进制 `tsc`（typescript@7，本机由 mise 装），预览通道
-- `tsgo`。都不在 Mason 稳定通道（mason 只有 tsgo 每夜版，且撞 min-release-age），
-- 故走 PATH 探测、不进 install plane 的 LSP_TOOLS；cmd 在 tsc/tsgo 间的解析在
-- lsp/tsc.lua。denols / oxlint（mason 系）在 LSP_TOOLS；deno_fmt/oxfmt 的 runtime
-- 分流在 plugins/format/conform.lua。
require("tools.lang_registry").register("typescript", {
	lsp = { tsc = { probe = { "tsc", "tsgo" } } },
})

return {}
