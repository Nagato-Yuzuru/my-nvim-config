-- DAP loader：扫描顶层 `dap/*.lua`，把每个 adapter 注入 nvim-dap 的
-- adapters / configurations 表。**镜像 lsp/ 的 per-server 拆分模型**。
--
-- 每个 dap/<name>.lua 必须 return 一个 spec table：
--   {
--     type                  = "delve",            -- key in dap.adapters；configs 通过 `type` 字段引用
--     mason                 = "delve",            -- 可选：mason 包名（缺省则不自动安装）
--     filetypes             = { "go" },           -- 把 configurations 注册到哪些 ft
--     adapter               = { ... },            -- nvim-dap adapter spec
--     configurations        = { ... },            -- list of debug configurations
--     exception_breakpoints = { "uncaught" },     -- 可选：启动 session 时默认开的 filter 列表
--                                                 -- （filter 名是 adapter-specific，见各 dap/*.lua）
--   }
--
-- setup() 由 plugins/runtime/dap.lua 在 nvim-dap 加载完后调用，并把收集到的
-- mason 包列表回传给 mason 安装入口。

local M = {}

-- 函数断点（function breakpoints）的轻量实现。
-- nvim-dap 没有高层 API，这里维护一个 name->true 表：
--   * toggle_function_breakpoint(name) 改表并（若 session 活）立即 apply
--   * apply_function_breakpoints()      发 setFunctionBreakpoints 请求
-- plugins/runtime/dap.lua 在 event_initialized 里会调 apply，让断点跟新
-- session 一起恢复。
local function_breakpoints = {}

function M.toggle_function_breakpoint(name)
	if not name or name == "" then
		return
	end
	if function_breakpoints[name] then
		function_breakpoints[name] = nil
		vim.notify(("Function breakpoint removed: %s"):format(name), vim.log.levels.INFO)
	else
		function_breakpoints[name] = true
		vim.notify(("Function breakpoint added: %s"):format(name), vim.log.levels.INFO)
	end
	M.apply_function_breakpoints()
end

function M.apply_function_breakpoints()
	local ok_dap, dap = pcall(require, "dap")
	if not ok_dap then
		return
	end
	local session = dap.session()
	if not session then
		return
	end
	local bps = {}
	for fname in pairs(function_breakpoints) do
		table.insert(bps, { name = fname })
	end
	session:request("setFunctionBreakpoints", { breakpoints = bps })
end

function M.list_function_breakpoints()
	local list = {}
	for fname in pairs(function_breakpoints) do
		table.insert(list, fname)
	end
	table.sort(list)
	return list
end

function M.setup()
	local ok_dap, dap = pcall(require, "dap")
	if not ok_dap then
		vim.notify("core.dap: nvim-dap not available", vim.log.levels.ERROR)
		return {}
	end

	local dap_dir = vim.fn.stdpath("config") .. "/dap"
	local mason_pkgs = {}

	if vim.fn.isdirectory(dap_dir) == 0 then
		return mason_pkgs
	end

	for _, file in ipairs(vim.fn.glob(dap_dir .. "/*.lua", true, true)) do
		local ok, spec = pcall(dofile, file)
		if not ok or type(spec) ~= "table" then
			vim.notify(
				("core.dap: failed to load %s\n%s"):format(file, tostring(spec)),
				vim.log.levels.ERROR
			)
		else
			if spec.type and spec.adapter then
				dap.adapters[spec.type] = spec.adapter
			end
			if spec.configurations and spec.filetypes then
				for _, ft in ipairs(spec.filetypes) do
					dap.configurations[ft] = spec.configurations
				end
			end
			-- 默认异常 filter 注入 dap.defaults[type].exception_breakpoints。
			-- filter 名是 adapter-specific，各 dap/*.lua 自己列：
			--   debugpy  => "uncaught"
			--   codelldb => "rust_panic" / "cpp_throw"
			--   delve    => "unrecovered-panic"
			--   js-debug => "uncaught"
			if spec.type and spec.exception_breakpoints then
				dap.defaults[spec.type] = dap.defaults[spec.type] or {}
				dap.defaults[spec.type].exception_breakpoints = spec.exception_breakpoints
			end
			if spec.mason then
				table.insert(mason_pkgs, spec.mason)
			end
		end
	end

	return mason_pkgs
end

-- 通过 mason-registry 直接安装（不依赖 mason-nvim-dap）。所有 mason 装的二进制
-- 都在 ~/.local/share/nvim/mason/bin（mason 启动时已加进 nvim 的 PATH），所以
-- 用 vim.fn.executable() 做 fast-path 判断。
function M.ensure_mason(pkgs)
	if vim.env.CI == "true" or vim.env.NO_AUTO_INSTALL == "1" then
		return
	end
	local ok, mr = pcall(require, "mason-registry")
	if not ok then
		return
	end
	for _, name in ipairs(pkgs) do
		local okp, pkg = pcall(mr.get_package, name)
		if okp and not pkg:is_installed() then
			vim.notify(("Installing %s via Mason…"):format(name), vim.log.levels.INFO)
			pkg:install()
		end
	end
end

return M
