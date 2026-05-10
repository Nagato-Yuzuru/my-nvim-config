-- Native code 调试器 (codelldb / Vadim Chugunov 的 LLDB 包装)
-- mason 包 `codelldb`，覆盖 C / C++ / Rust。
-- 用 codelldb 而不是 lldb-vscode：前者 setup 简单，对 Rust 的 pretty-printers
-- 支持更好。

---@type DapSpec
return {
	type = "codelldb",
	mason = "codelldb",
	filetypes = { "c", "cpp", "rust" },
	-- session 启动时默认订阅 Rust panic 和 C++ throw。想调整用 `<leader>dX`。
	-- codelldb 支持的 filter（从 adapter capabilities 拿到）：
	--   rust_panic / cpp_throw / cpp_catch / swift_throw
	exception_breakpoints = { "rust_panic", "cpp_throw" },
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
		-- Post-mortem：加载 core dump 到进程现场。
		-- codelldb 通过 `coreDumpPath` 支持；binary 要和 core 对应（glibc / rust-libstd 版本）。
		{
			type = "codelldb",
			request = "attach",
			name = "Attach core dump",
			program = function()
				return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
			end,
			coreDumpPath = function()
				return vim.fn.input("Path to core file: ", vim.fn.getcwd() .. "/", "file")
			end,
			cwd = "${workspaceFolder}",
		},
		-- 远端 lldb-server / debugserver：目标机已起 `lldb-server g :PORT <binary>`，
		-- 本地通过 codelldb 的 `processCreateCommands` 走 lldb `gdb-remote` 连过去。
		{
			type = "codelldb",
			request = "launch",
			name = "Attach remote (prompt host:port)",
			program = function()
				return vim.fn.input("Path to local executable (for symbols): ", vim.fn.getcwd() .. "/", "file")
			end,
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
			processCreateCommands = function()
				local host = vim.fn.input("Remote host [127.0.0.1]: ")
				host = (host ~= "" and host) or "127.0.0.1"
				local port = vim.fn.input("Remote port: ", "1234")
				return { ("gdb-remote %s:%s"):format(host, port) }
			end,
		},
	},
}
