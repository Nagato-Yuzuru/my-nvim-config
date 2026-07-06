-- zls：Zig 官方 LSP。二进制由 mise 提供（PATH 优先探测），Mason 兜底登记见
-- tools/mason_ensure.lua 的 LSP_TOOLS。常规 native-enable——不像 rust_analyzer 需要
-- external_owner，没有插件接管 zls 的生命周期，vim.lsp.enable 直接启即可。
--
-- 没有 settings 块是刻意的：zls 默认值已经匹配本配置的 IDE 化取向——
-- enable_argument_placeholders（≈ gopls 的 usePlaceholders）/ enable_snippets /
-- inlay_hints_show_* 全默认 true，semantic_tokens 默认 "full"。诊断质量的关键
-- enable_build_on_save 默认 null（自动：仓库有 build.zig 时跑 `zig build` 给出真实
-- 编译诊断，等价于 Go 侧 golangci-lint；无 build.zig 的散文件退化为纯 AST/语法
-- 诊断）。把这些 key 写死只会与上游默认重复，凭空多一处要跟 zls 版本对齐的漂移点。
--
-- filetypes 只列 "zig"：Neovim 运行时把 *.zig / build.zig.zon / *.zon 一律判为
-- ft=zig（v0.12 实测），没有独立的 zon filetype——写 "zon" 是永不命中的死配置。
return {
	cmd = { "zls" },
	filetypes = { "zig" },
	root_markers = { "build.zig", "build.zig.zon", ".git" },
}
