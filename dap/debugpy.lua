-- Python 调试器 (debugpy)
-- mason 包 `debugpy` 提供 `debugpy-adapter` 二进制（adapter 端）。
-- 注意：被调试进程也需要 debugpy 包，必须装在项目环境里：
--   uv add --dev debugpy
--
-- Post-mortem debug：debugpy 不原生支持 core dump / post-mortem。
-- 想在崩溃后复盘栈状态，走 pdb 外部流程：
--   uv run python -m pdb -c continue script.py
-- 或程序里 `import pdb; pdb.post_mortem()` —— 不经过 DAP。

-- Python 解释器解析顺序（强→弱信号）：
--   1. $VIRTUAL_ENV/bin/python   (用户 shell 里显式激活了 venv，最可信)
--   2. project root + 常见 venv 目录: .venv / venv / .env / env
--   3. PATH 上的 python3
--   4. 字符串 "python3"（最后兜底）
-- 不假设 cwd —— 用 vim.fs.root 顺着 buffer 找项目根，跟 lsp/pyright.lua 一致。
local function project_root()
	local bufname = vim.api.nvim_buf_get_name(0)
	if bufname == "" then
		return vim.uv.cwd()
	end
	local root = vim.fs.root(
		0,
		{ "pyproject.toml", "setup.py", "setup.cfg", "Pipfile", "requirements.txt", ".git" }
	)
	return root or vim.fs.dirname(bufname) or vim.uv.cwd()
end

local function find_python()
	if vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV ~= "" then
		local p = vim.env.VIRTUAL_ENV .. "/bin/python"
		if vim.fn.executable(p) == 1 then
			return p
		end
	end

	local root = project_root()
	if root then
		for _, dir in ipairs({ ".venv", "venv", ".env", "env" }) do
			local p = root .. "/" .. dir .. "/bin/python"
			if vim.fn.executable(p) == 1 then
				return p
			end
		end
	end

	local sys = vim.fn.exepath("python3")
	return sys ~= "" and sys or "python3"
end

---@type DapSpec
return {
	type = "python",
	mason = "debugpy",
	filetypes = { "python" },
	-- 默认 session 开启时自动订阅未捕获异常 filter（debugpy 支持的 filter
	-- 名：raised / uncaught / userUnhandled）。`<leader>dX` 可交互覆盖。
	exception_breakpoints = { "uncaught" },
	adapter = {
		type = "executable",
		command = "debugpy-adapter",
		args = {},
	},
	configurations = {
		{
			type = "python",
			request = "launch",
			name = "Launch file",
			program = "${file}",
			pythonPath = find_python,
			justMyCode = false,
		},
		{
			type = "python",
			request = "launch",
			name = "Launch module",
			module = function()
				return vim.fn.input("Module name: ")
			end,
			pythonPath = find_python,
			justMyCode = false,
		},
		{
			type = "python",
			request = "launch",
			name = "Launch pytest (current file)",
			module = "pytest",
			args = { "${file}", "-s", "-v" },
			pythonPath = find_python,
			justMyCode = false,
		},
		{
			type = "python",
			request = "attach",
			name = "Attach (prompt host:port)",
			connect = function()
				local host = vim.fn.input("Host [127.0.0.1]: ")
				host = (host ~= "" and host) or "127.0.0.1"
				local port = tonumber(vim.fn.input("Port [5678]: ", "5678")) or 5678
				return { host = host, port = port }
			end,
		},
	},
}
