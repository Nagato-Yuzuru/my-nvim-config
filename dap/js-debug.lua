-- Node / TypeScript 调试器 (Microsoft js-debug)
-- mason 包 `js-debug-adapter`；type 名 "pwa-node" 是上游约定（pwa = preview /
-- pretty web apps，新一代 vscode-js-debug 全部走 pwa-* 前缀）。

return {
	type = "pwa-node",
	mason = "js-debug-adapter",
	filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
	adapter = {
		type = "server",
		host = "localhost",
		port = "${port}",
		executable = {
			command = "js-debug-adapter",
			args = { "${port}" },
		},
	},
	configurations = {
		-- runtimeExecutable = "node" 走 PATH 解析（nvm/fnm/asdf 切换的 node 也吃）。
		-- TS 文件直接 launch 会因为 sourcemap 缺失出问题 —— 不给"用 tsx 跑 TS"
		-- 这种快捷配置，理由：tsx 是项目级工具（不一定全局有），且 source map
		-- 经常不可靠；TS 的正路是先编出 dist/ 再 launch，或者项目自带
		-- .vscode/launch.json（nvim-dap 会自动读取）。
		{
			type = "pwa-node",
			request = "launch",
			name = "Launch file",
			program = "${file}",
			cwd = "${workspaceFolder}",
			runtimeExecutable = "node",
			sourceMaps = true,
			skipFiles = { "<node_internals>/**", "node_modules/**" },
		},
		{
			type = "pwa-node",
			request = "attach",
			name = "Attach to process",
			processId = function()
				return require("dap.utils").pick_process()
			end,
			cwd = "${workspaceFolder}",
			sourceMaps = true,
		},
	},
}
