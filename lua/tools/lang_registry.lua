-- Language plane 注册表（两平面模型的语言侧；install plane 见 tools/mason_ensure.lua）。
--
-- 每个语言域文件（plugins/lang/<x>.lua）在**顶层**调用 M.register() 声明本语言的
-- 事实，随 lazy.setup() 的 spec import（init.lua）在启动早期执行；消费者随后读取：
--   * init.lua     → M.apply_ft()            聚合后一次性 vim.filetype.add
--   * core/lsp.lua → M.enabled_lsp_servers() 探测通过的 server 交给 vim.lsp.enable
--
-- 与 install plane 的分工（用户决策，2026-08-15）：
--   * "哪些东西被 Mason 管"必须集中一处可查——mason 系 server/formatter/linter 的
--     安装清单**手写集中**在 mason_ensure.lua，不从本注册表派生；
--   * 本表只承载语言行为事实：ft detection、非 mason server 的 enablement 探测、
--     进程内 server。treesitter parser 清单同属安装清单，集中在 plugins/treesitter.lua。
--
-- 校验一律 fail loud：重复语言 / 重复 server / 重复 ft 键 / 未知字段都在
-- register() 当场 error——写错字段名要立刻炸，不要静默吞掉半个语言。

---@class LangLspSpec
---@field probe? string|string[]|fun():boolean 省略 = 无条件 enable。string = 单二进制
---       executable() 探测；string[] = 任一命中即过；function = 自定义探测（工具链系）。
---@field in_process? boolean 进程内 server（无外部二进制）：不进 lsp_root 的
---       root/cwd 防御（apply_safe_defaults 只对外部进程 server 有意义）。

---@class LangSpec
---@field ft? table vim.filetype.add() 原形参数（extension / filename / pattern）
---@field lsp? table<string, LangLspSpec> server 名（对应 lsp/<server>.lua）→ 探测声明

local M = {}

---@type table<string, LangSpec>
local langs = {}
---@type table<string, string> server 名 → 注册它的语言（跨语言撞名检测）
local server_owner = {}
---@type table<string, string> "kind:key" → 注册它的语言（跨语言 ft 撞键检测）
local ft_owner = {}

local SPEC_KEYS = { ft = true, lsp = true }
local LSP_KEYS = { probe = true, in_process = true }
local FT_KINDS = { extension = true, filename = true, pattern = true }

---@param name string 语言名（语言域文件名，如 "promql"）
---@param spec LangSpec
function M.register(name, spec)
	if type(name) ~= "string" or name == "" then
		error("lang_registry: language name must be a non-empty string")
	end
	if langs[name] then
		error(("lang_registry: duplicate language %q"):format(name))
	end
	if type(spec) ~= "table" then
		error(("lang_registry: spec for %q must be a table"):format(name))
	end
	for k in pairs(spec) do
		if not SPEC_KEYS[k] then
			error(("lang_registry: unknown spec key %q in language %q"):format(tostring(k), name))
		end
	end
	if spec.ft ~= nil then
		if type(spec.ft) ~= "table" then
			error(("lang_registry: ft of %q must be a table"):format(name))
		end
		for kind, entries in pairs(spec.ft) do
			if not FT_KINDS[kind] then
				error(("lang_registry: unknown ft kind %q in language %q"):format(tostring(kind), name))
			end
			for key in pairs(entries) do
				local owner_key = kind .. ":" .. key
				local owner = ft_owner[owner_key]
				if owner then
					error(
						("lang_registry: ft %s %q already registered by %q (conflict from %q)"):format(
							kind,
							key,
							owner,
							name
						)
					)
				end
				ft_owner[owner_key] = name
			end
		end
	end
	if spec.lsp ~= nil then
		if type(spec.lsp) ~= "table" then
			error(("lang_registry: lsp of %q must be a table"):format(name))
		end
		for server, entry in pairs(spec.lsp) do
			if type(server) ~= "string" then
				error(("lang_registry: lsp server names in %q must be strings"):format(name))
			end
			local owner = server_owner[server]
			if owner then
				error(
					("lang_registry: server %q already registered by %q (conflict from %q)"):format(server, owner, name)
				)
			end
			if type(entry) ~= "table" then
				error(("lang_registry: lsp entry %q in %q must be a table"):format(server, name))
			end
			for k in pairs(entry) do
				if not LSP_KEYS[k] then
					error(("lang_registry: unknown lsp key %q on server %q in %q"):format(tostring(k), server, name))
				end
			end
			local pt = type(entry.probe)
			if not (pt == "nil" or pt == "string" or pt == "table" or pt == "function") then
				error(("lang_registry: probe of server %q in %q must be string|string[]|function"):format(server, name))
			end
			server_owner[server] = name
		end
	end
	langs[name] = spec
end

-- 聚合全部语言的 ft 声明，单点调用 vim.filetype.add（一次）。调用点在 init.lua，
-- 位于 lazy.setup()（语言域文件 import 完毕）之后、首个 buffer 加载之前。
function M.apply_ft()
	local merged = {}
	for _, spec in pairs(langs) do
		for kind, entries in pairs(spec.ft or {}) do
			merged[kind] = merged[kind] or {}
			for key, value in pairs(entries) do
				merged[kind][key] = value
			end
		end
	end
	if next(merged) then
		vim.filetype.add(merged)
	end
end

---@param probe string|string[]|fun():boolean|nil
---@return boolean
local function probe_ok(probe)
	if probe == nil then
		return true
	end
	if type(probe) == "string" then
		return vim.fn.executable(probe) == 1
	end
	if type(probe) == "table" then
		for _, bin in ipairs(probe) do
			if vim.fn.executable(bin) == 1 then
				return true
			end
		end
		return false
	end
	return probe() == true
end

-- 探测通过的 server 名单，按 server 名排序保证 enable 顺序确定性。
-- external 走 lsp_root.apply_safe_defaults + vim.lsp.enable；in_process 只 enable。
---@return { external: string[], in_process: string[] }
function M.enabled_lsp_servers()
	local names = {}
	for server in pairs(server_owner) do
		table.insert(names, server)
	end
	table.sort(names)
	local out = { external = {}, in_process = {} }
	for _, server in ipairs(names) do
		local entry = langs[server_owner[server]].lsp[server]
		if probe_ok(entry.probe) then
			table.insert(entry.in_process and out.in_process or out.external, server)
		end
	end
	return out
end

-- 已注册内容的深拷贝快照（测试 / 迁移期 golden 对照用；生产消费者走上面两个出口）。
---@return table<string, LangSpec>
function M.declared() return vim.deepcopy(langs) end

return M
