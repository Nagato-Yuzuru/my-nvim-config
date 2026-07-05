-- DAP loader：扫描顶层 `dap/*.lua`，把每个 adapter 注入 nvim-dap 的
-- adapters / configurations 表。**镜像 lsp/ 的 per-server 拆分模型**。
--
-- 每个 dap/<name>.lua 必须 return 一个 DapSpec（见下方 class 定义）。
-- setup() 由 plugins/runtime/dap.lua 在 nvim-dap 加载完后调用，并把收集到的
-- mason 包列表回传给 mason 安装入口。

---@class DapSpec
---@field type string nvim-dap adapters key; configurations[].type 引用此值
---@field mason? string mason-registry 包名（缺省则不自动安装）
---@field filetypes string[] 把 configurations 注册到哪些 filetype
---@field adapter table nvim-dap adapter spec（executable / server / pipe）
---@field configurations table[] debug configurations 列表
---@field exception_breakpoints? string[] adapter-specific filter 名列表（启动 session 时默认订阅）

---@class DapMasonPkg
---@field name string mason package name
---@field bin? string PATH probe binary (nil = 仅靠 mason 装)

local M = {}

-- 函数断点（function breakpoints）的轻量实现。
-- nvim-dap 没有高层 API，这里维护一个 name->true 表：
--   * toggle_function_breakpoint(name) 改表并（若 session 活）立即 apply
--   * apply_function_breakpoints()      发 setFunctionBreakpoints 请求
-- plugins/runtime/dap.lua 在 event_initialized 里会调 apply，让断点跟新
-- session 一起恢复。
---@type table<string, true>
local function_breakpoints = {}

---@param name string?
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

---@return string[] sorted function-breakpoint names
function M.list_function_breakpoints()
	local list = {}
	for fname in pairs(function_breakpoints) do
		table.insert(list, fname)
	end
	table.sort(list)
	return list
end

---@return DapMasonPkg[] mason packages collected from all dap/*.lua specs
function M.setup()
	local ok_dap, dap = pcall(require, "dap")
	if not ok_dap then
		vim.notify("core.dap: nvim-dap not available", vim.log.levels.ERROR)
		return {}
	end

	local dap_dir = vim.fn.stdpath("config") .. "/dap"
	---@type DapMasonPkg[]
	local mason_pkgs = {}

	if vim.fn.isdirectory(dap_dir) == 0 then
		return mason_pkgs
	end

	for _, file in ipairs(vim.fn.glob(dap_dir .. "/*.lua", true, true)) do
		---@type boolean, DapSpec|string
		local ok, spec = pcall(dofile, file)
		if not ok or type(spec) ~= "table" then
			vim.notify(("core.dap: failed to load %s\n%s"):format(file, tostring(spec)), vim.log.levels.ERROR)
		else
			if spec.type and spec.adapter then
				dap.adapters[spec.type] = spec.adapter
			end
			if spec.configurations and spec.filetypes then
				for _, ft in ipairs(spec.filetypes) do
					-- append 而非覆盖：两个 adapter 文件可能合法共享同一 filetype，
					-- "往 dap/ 丢文件" 不应互相清空对方的 configurations。
					dap.configurations[ft] = vim.list_extend(dap.configurations[ft] or {}, spec.configurations)
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
				table.insert(mason_pkgs, { name = spec.mason, bin = M.adapter_bin(spec) })
			end
		end
	end

	return mason_pkgs
end

-- 从 adapter spec 里抽出运行时真正调用的 bin 名。
--   executable 型 => adapter.command
--   server 型     => adapter.executable.command
--   其它（纯远端 server 等）=> nil，表示无法探测 PATH、只能交给 mason
---@param spec DapSpec
---@return string?
function M.adapter_bin(spec)
	local a = spec.adapter
	if type(a) ~= "table" then
		return nil
	end
	if type(a.command) == "string" then
		return a.command
	end
	if type(a.executable) == "table" and type(a.executable.command) == "string" then
		return a.executable.command
	end
	return nil
end

-- 通过 mason-registry 直接安装（不依赖 mason-nvim-dap）。
-- 镜像 LSP 那一侧的 env-first 策略：先 `vim.fn.executable()` 看 bin 是否已经
-- 在 PATH 上拿得到（go install 来的 dlv、brew 装的 codelldb、mason 上次装好
-- 的都算），命中就跳过 mason 安装。mason 启动时会把 `~/.local/share/nvim/
-- mason/bin` 追加到 PATH，所以 mason 先前装过的二进制也会在这一步命中。
---@param pkgs DapMasonPkg[]
function M.ensure_mason(pkgs)
	if vim.env.CI == "true" or vim.env.NO_AUTO_INSTALL == "1" then
		return
	end
	local install_if_missing = require("tools.mason_install").install_if_missing
	for _, p in ipairs(pkgs) do
		if p.bin and vim.fn.executable(p.bin) == 1 then
			-- 已在 PATH，mason 不用插手
		else
			install_if_missing(p.name)
		end
	end
end

return M
