-- :PyVersion 的引擎：session 级覆盖 ruff / ty 的 Python 版本。
--   * lsp/ruff.lua、lsp/ty.lua 的 before_init 在每个 client 启动时注入当前版本，
--     走两者的内联配置（优先于项目文件）。只在启动时读，所以改版本要重启 client。
--   * ty 的 settings 必须原地写：client.settings 在 before_init 之前已引用
--     config.settings，换表无效。config 是每个 client 的深拷贝，不会写脏共享配置。

local M = {}

M.SERVERS = { "ruff", "ty" }

---@type string? "3.10" 形式；nil = 不覆盖
local version = nil

-- 接受 "3.10" / "py310"，统一成 "3.10"。不卡上限，越界由 server 报错。
---@param arg string
---@return string? version
---@return string? err
function M.normalize(arg)
	arg = vim.trim(arg)
	local minor = arg:match("^3%.(%d%d?)$") or arg:match("^py3(%d%d?)$")
	if not minor then
		return nil, ("invalid Python version %q (expected e.g. 3.10 or py310)"):format(arg)
	end
	return "3." .. tonumber(minor)
end

-- 取 `--help` 里 "[possible values: ...]" 中的版本（ruff 写 py310，ty 写 3.10）。
---@param help string
---@return string[]
function M.parse_help_versions(help)
	local out = {}
	for list in help:gmatch("%[possible values: ([^%]]*)%]") do
		for item in vim.gsplit(list, ",%s*") do
			local v = M.normalize(item)
			if v then
				table.insert(out, v)
			end
		end
	end
	return out
end

local HELP_CMDS = {
	ruff = { "ruff", "check", "--help" },
	ty = { "ty", "check", "--help" },
}

---@type string[]?
local supported_cache = nil

-- 补全候选：已安装的 ruff / ty 都支持的版本，session 内缓存。
---@return string[]
function M.supported()
	if supported_cache then
		return supported_cache
	end
	local common ---@type table<string, true>?
	for _, name in ipairs(M.SERVERS) do
		if vim.fn.executable(name) == 1 then
			local res = vim.system(HELP_CMDS[name], { text = true }):wait(2000)
			local set = {}
			for _, v in ipairs(M.parse_help_versions(res.stdout or "")) do
				if not common or common[v] then
					set[v] = true
				end
			end
			common = set
		end
	end
	local list = vim.tbl_keys(common or {})
	table.sort(list, function(a, b) return tonumber(a:match("%d+$")) < tonumber(b:match("%d+$")) end)
	supported_cache = list
	return list
end

---@return string?
function M.get() return version end

---@param v string? 已 normalize 的版本；nil 清除覆盖
function M.set(v) version = v end

---@param params lsp.InitializeParams
---@param config vim.lsp.ClientConfig
function M.ruff_before_init(params, config)
	if not version then
		return
	end
	local target = "py3" .. version:match("^3%.(%d+)$")
	local init_options = vim.tbl_deep_extend(
		"force",
		config.init_options or {},
		{ settings = { configuration = { ["target-version"] = target } } }
	)
	config.init_options = init_options
	params.initializationOptions = init_options
end

---@param _ lsp.InitializeParams
---@param config vim.lsp.ClientConfig
function M.ty_before_init(_, config)
	if not version then
		return
	end
	local settings = assert(config.settings, "lsp/ty.lua must declare a settings table (written in place)")
	settings.ty = settings.ty or {}
	settings.ty.configuration = settings.ty.configuration or {}
	settings.ty.configuration.environment = settings.ty.configuration.environment or {}
	settings.ty.configuration.environment["python-version"] = version
end

-- 只重启已在跑的 server，免得把没装的 enable 起来。重复 enable 会对所有 buffer
-- 重放 FileType 回调，重新 attach。
---@return string[] restarted server 名
function M.restart()
	local names, clients = {}, {}
	for _, name in ipairs(M.SERVERS) do
		local cs = vim.lsp.get_clients({ name = name })
		if #cs > 0 then
			table.insert(names, name)
			vim.list_extend(clients, cs)
		end
	end
	if #names == 0 then
		return names
	end
	for _, c in ipairs(clients) do
		c:stop()
	end
	local function all_stopped()
		return vim.iter(clients):all(function(c) return c:is_stopped() end)
	end
	if not vim.wait(3000, all_stopped, 20) then
		for _, c in ipairs(clients) do
			c:stop(true)
		end
	end
	-- nvim 0.12 detach 不清 pull 诊断（还有别的 pull client 时），旧诊断会残留；
	-- 按 get_namespace 的命名 nvim.lsp.<name>.<id>[.<identifier>] 手动清。
	for ns_name, ns in pairs(vim.api.nvim_get_namespaces()) do
		for _, c in ipairs(clients) do
			local prefix = ("nvim.lsp.%s.%d"):format(c.name, c.id)
			if ns_name == prefix or vim.startswith(ns_name, prefix .. ".") then
				vim.diagnostic.reset(ns)
			end
		end
	end
	vim.lsp.enable(names)
	return names
end

return M
