-- sourcekit-lsp：Apple 官方 Swift LSP，随 Swift 工具链（Xcode CLT / swiftly）来，
-- 不是 Mason 包 → 不在 tools/mason_ensure.lua 的 LSP_TOOLS。改由 core/lsp.lua 的
-- enable_servers 按存在探测决定是否 enable（同 Scheme 三兄弟的 toolchain-probed
-- 路子），无 Swift 环境（Linux / 未装 CLT）时不挂、不刷 "client quit"。
--
-- cmd：本机 /usr/bin/sourcekit-lsp 直接在 PATH（CLT 自带），裸名即可；但工具链
-- 二进制并不保证都上裸 PATH——同工具链的 swift-format 就只有 `xcrun swift-format`
-- 可达——故缺失时回落 `xcrun sourcekit-lsp` 跟随激活工具链。cmd 必须是 table，
-- lsp_root.apply_safe_defaults 才能包 cmd_with_safe_cwd（单文件模式截断 cwd）。
--
-- filetypes 只列 "swift"：sourcekit-lsp 也能接 objc/c/cpp，但那些已归 clangd，
-- 同一 buffer 双挂两个 client 只会打架。纯 Swift 编辑只需 swift。
--
-- root_markers 只列 Package.swift + .git：纯 SwiftPM 取向（不做 Xcode 工程，故不
-- 列 *.xcodeproj / buildServer.json 这类 BSP 标记——真要接 Xcode 工程时再加，配套
-- 装 xcode-build-server 生成 buildServer.json）。散文件（无 Package.swift）经
-- lsp_root 退化为 single-file 模式，不会把 $HOME 注册成 workspace。
--
-- 没有 settings 块是刻意的：Swift 6.1+ 工具链**默认开启** background indexing
-- （跨文件引用 / 调用层级 / rename 依赖它），无需再写 ~/.sourcekit-lsp/config.json；
-- 把默认值写死只会凭空多一处要跟工具链版本对齐的漂移点。
local cmd = vim.fn.executable("sourcekit-lsp") == 1 and { "sourcekit-lsp" } or { "xcrun", "sourcekit-lsp" }

return {
	cmd = cmd,
	filetypes = { "swift" },
	root_markers = { "Package.swift", ".git" },
}
