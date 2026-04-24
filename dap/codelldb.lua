-- Native code 调试器 (codelldb / Vadim Chugunov 的 LLDB 包装)
-- mason 包 `codelldb`，覆盖 C / C++ / Rust。
-- 用 codelldb 而不是 lldb-vscode：前者 setup 简单，对 Rust 的 pretty-printers
-- 支持更好。

return {
	type = "codelldb",
	mason = "codelldb",
	filetypes = { "c", "cpp", "rust" },
	adapter = {
		type = "server",
		port = "${port}",
		executable = {
			command = "codelldb",
			args = { "--port", "${port}" },
		},
	},
	configurations = {
		{
			type = "codelldb",
			request = "launch",
			name = "Launch executable",
			program = function()
				return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
			end,
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
			args = {},
		},
		{
			type = "codelldb",
			request = "attach",
			name = "Attach to process",
			pid = function()
				return require("dap.utils").pick_process()
			end,
			cwd = "${workspaceFolder}",
		},
	},
}
