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
	init_options = {
		fallbackFlags = { "-std=c++20" },
	},
}
