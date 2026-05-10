-- Steel LSP（steel-language-server）。Rust 嵌入式 Scheme，是 "Rust 怎么 host
-- 一个 Scheme" 的活教材——直接对应用户在写的 Scheme→WASM transpiler 项目。
--
-- 安装：cargo install --git https://github.com/mattwparas/steel steel-language-server
-- （crate 名以 Steel 仓库当时为准，由 lua/tools/scheme_toolchain.lua 探测 + 提示）。
--
-- filetypes 同时声明 scheme：Steel 文件常用 .scm 扩展。Guile / Steel 共享
-- scheme filetype，靠 root_markers 区分——Steel 项目典型有 cog.scm / Cargo.toml
-- 加 steel 依赖。两个 LSP 都没匹配就不启动（Conjure 仍可基于 generic REPL 工作）。
return {
	cmd = { "steel-language-server" },
	filetypes = { "scheme" },
	root_markers = { "cog.scm", "Cargo.toml", ".git" },
}
