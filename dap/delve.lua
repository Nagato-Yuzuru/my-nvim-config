-- Go 调试器 (delve)
-- mason 包 `delve` 提供 `dlv` 二进制；mason 启动时已把 mason/bin 加入 PATH。

return {
	type = "delve",
	mason = "delve",
	filetypes = { "go" },
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
			processId = function()
				return require("dap.utils").pick_process()
			end,
		},
	},
}
