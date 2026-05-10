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
-- 到一个 Guile 项目特征文件（.guile / Makefile + autogen.sh 这类）就启动；
-- 否则不启动，Steel LSP 接管。
return {
	cmd = { "guile-lsp-server" },
	filetypes = { "scheme" },
	root_markers = { ".guile", "guix.scm", "configure.ac", ".git" },
}
