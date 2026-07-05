-- Guile LSP（guile-lsp-server）。Hoot 项目（Guile → WASM）面试准备用的副实现。
--
-- 安装：mason 不提供。macOS 上 brew 没现成包，最稳妥是源码编译：
--   git clone https://codeberg.org/rgherdt/scheme-lsp-server
--   make && make install   # 需要 guile + scheme 基础设施
-- 或者通过 guix install guile-lsp-server。具体路径由 lua/tools/scheme_toolchain.lua
-- 在打开 .scm 时探测并提示。
--
-- filetypes 只声明 scheme：Steel 也走 .scm，但它有自己独立的 LSP（见
-- steel_language_server.lua），靠 root_markers 区分项目。Guile 这边匹配
-- 到一个 Guile 项目特征文件（.guile / guix.scm / configure.ac）就启动；
-- 否则不启动，Steel LSP 接管。
--
-- 故意不把 .git 当兜底 marker：Guile / Steel 共享 scheme filetype，若两边都
-- 拿 .git 兜底，任何 git 仓库里的散 .scm 都会同时命中 → 两个 LSP 双挂。宁可
-- 不启动也不双挂（Conjure 的 generic REPL 无 LSP 也能用）。
return {
	cmd = { "guile-lsp-server" },
	filetypes = { "scheme" },
	root_markers = { ".guile", "guix.scm", "configure.ac" },
}
