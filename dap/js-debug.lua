-- Node / TypeScript 调试器 (Microsoft js-debug)
-- mason 包 `js-debug-adapter`；type 名 "pwa-node" 是上游约定（pwa = preview /
-- pretty web apps，新一代 vscode-js-debug 全部走 pwa-* 前缀）。

---@type DapSpec
return {
	type = "pwa-node",
	mason = "js-debug-adapter",
	filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
	-- session 启动默认订阅未捕获异常。js-debug 支持的 filter：
	--   all / uncaught / promise
	exception_breakpoints = { "uncaught" },
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
			processId = function() return require("dap.utils").pick_process() end,
			cwd = "${workspaceFolder}",
			sourceMaps = true,
		},
		-- 远端 Node：目标进程用 `node --inspect=0.0.0.0:9229 app.js` 起来，
		-- 本地通过 pwa-node 走 Inspector protocol 连过去。
		{
			type = "pwa-node",
			request = "attach",
			name = "Attach remote (prompt host:port)",
			address = function()
				local h = vim.fn.input("Remote host [127.0.0.1]: ")
				return (h ~= "" and h) or "127.0.0.1"
			end,
			port = function()
				local p = vim.fn.input("Remote port [9229]: ", "9229")
				return tonumber(p) or 9229
			end,
			cwd = "${workspaceFolder}",
			sourceMaps = true,
			skipFiles = { "<node_internals>/**", "node_modules/**" },
		},
	},
}
