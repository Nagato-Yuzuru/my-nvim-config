-- Go 调试器 (delve)
-- mason 包 `delve` 提供 `dlv` 二进制；mason 启动时已把 mason/bin 加入 PATH。
--
-- 输出管道：delve 默认**不**把被调试程序的 stdout/stderr 转成 DAP output
-- events（落在 dlv 进程自己的 stdout 上，编辑器里看不见——log.Fatalln 的
-- 遗言会无声消失）。因此所有 launch 型配置显式 `outputMode = "remote"`，
-- 程序输出经 output events 进 REPL 面板（<leader>dvr / ,r；Console 面板是
-- terminal 元素，delve 不走 runInTerminal，恒空）。attach/core/remote 不
-- 适用——进程 stdout 不归 delve 管。neotest 的 debug-nearest 同配
--（plugins/runtime/neotest.lua 的 dap_manual_config）。
--
-- 程序参数：launch 型配置的 args 走 core.dap.prompt_args（语义见该函数注
-- 释）。delve 特有：test 模式下 args 直接传给测试二进制，go test 风格的
-- flag 要写 `-test.` 前缀（-test.run / -test.v）。

local prompt_args = require("core.dap").prompt_args

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
			outputMode = "remote",
			args = prompt_args("delve:Debug package"),
		},
		{
			type = "delve",
			name = "Debug file",
			request = "launch",
			program = "${file}",
			outputMode = "remote",
			args = prompt_args("delve:Debug file"),
		},
		{
			type = "delve",
			name = "Debug test (file)",
			request = "launch",
			mode = "test",
			program = "${file}",
			outputMode = "remote",
			args = prompt_args("delve:Debug test (file)"),
		},
		{
			type = "delve",
			name = "Debug test (package)",
			request = "launch",
			mode = "test",
			program = "./${relativeFileDirname}",
			outputMode = "remote",
			args = prompt_args("delve:Debug test (package)"),
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
