-- 语言域：C。只有一条 ft 事实。clangd 在 lsp/clangd.lua（也服务 cpp 等），codelldb
-- 在 dap/codelldb.lua（与 cpp/rust/zig 共享），c parser 是 Neovim 内置。
--
-- .h 默认判 cpp，这里翻成 c（影响 treesitter/ftplugin/conform；clangd 不看 ft）。
-- 用 Vim 开关而不是 lang_registry 的 ft.extension.h：开关只改默认分支，registry
-- 会替换整个内置检测。C++ 项目的 .h 也会变 c，届时再改。
vim.g.c_syntax_for_h = 1

return {}
