-- clangd：C/C++/ObjC/CUDA/proto 的 LSP。clang-tidy（--clang-tidy）和 clang-format
--（formatting 走内嵌 libFormat，conform 的 lsp_fallback 直接用）都在这个进程里，
-- 不另挂 nvim-lint / conform 条目。二进制 PATH 优先，Mason 兜底见 mason_ensure.lua。
--
-- 不设 fallbackFlags：-std / -I / -D / -target 归项目（compile_commands.json；
-- 没构建系统就 compile_flags.txt 或 .clangd）。以前的 `-std=c++20` 会让没有
-- compile db 的裸 .c 第一行报 "not allowed with 'C'"。
return {
	cmd = {
		"clangd",
		"--background-index",
		"--clang-tidy",
		"--header-insertion=never",
		"--offset-encoding=utf-16",
	},
	filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
	root_markers = { "compile_commands.json", "compile_flags.txt", ".clangd", ".git" },
}
