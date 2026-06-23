-- Go 调试器 (delve)
-- mason 包 `delve` 提供 `dlv` 二进制；mason 启动时已把 mason/bin 加入 PATH。

---@type DapSpec
return {
	type = "delve",
	mason = "delve",
	filetypes = { "go" },
	-- session 启动默认订阅 unrecovered-panic。delve 的 filter 名：
	--   all / unrecovered-panic
	exception_breakpoints = { "unrecovered-panic" },
	adapter = {
		type = "server",
		port = "${port}",
		executable = {
			command = "dlv",
			args = { "dap", "-l", "127.0.0.1:${port}" },
		},
	},
	configurations = {
		-- 默认放第一个：debug 当前文件所在的 package（编 main 出 binary 跑），
		-- 比 ${file} 单文件模式更常用 —— 大多 Go 项目 main.go 跟其它源文件分包，
		-- 单文件 launch 经常因为 "main redeclared" 之类编不过。
		{
			type = "delve",
			name = "Debug package",
			request = "launch",
			program = "${fileDirname}",
		},
		{
			type = "delve",
			name = "Debug file",
			request = "launch",
			program = "${file}",
		},
		{
			type = "delve",
			name = "Debug test (file)",
			request = "launch",
			mode = "test",
			program = "${file}",
		},
		{
			type = "delve",
			name = "Debug test (package)",
			request = "launch",
			mode = "test",
			program = "./${relativeFileDirname}",
		},
		{
			type = "delve",
			name = "Attach to process",
			request = "attach",
			mode = "local",
			processId = function() return require("dap.utils").pick_process() end,
		},
		-- Post-mortem：加载 core dump（程序得用 `GOTRACEBACK=crash` 或 `dlv debug --core` 产出）。
		{
			type = "delve",
			name = "Debug core dump",
			request = "launch",
			mode = "core",
			program = function() return vim.fn.input("Path to Go binary: ", vim.fn.getcwd() .. "/", "file") end,
			coreFilePath = function() return vim.fn.input("Path to core file: ", vim.fn.getcwd() .. "/", "file") end,
		},
		-- 远程：目标机已跑 `dlv debug --headless --listen=:PORT --api-version=2`，
		-- 本地 attach 过去。mode = "remote"。
		{
			type = "delve",
			name = "Attach headless remote (prompt host:port)",
			request = "attach",
			mode = "remote",
			host = function()
				local h = vim.fn.input("Remote host [127.0.0.1]: ")
				return (h ~= "" and h) or "127.0.0.1"
			end,
			port = function()
				local p = vim.fn.input("Remote port [2345]: ", "2345")
				return tonumber(p) or 2345
			end,
		},
	},
}
