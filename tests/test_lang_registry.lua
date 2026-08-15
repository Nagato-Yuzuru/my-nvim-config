-- lua/tools/lang_registry.lua 的注册 / 校验 / 探测 / 聚合测试。
-- 注册表是模块级状态，每个 case 重新 require 拿全新实例；collector 进程内直接跑
--（无需 child——只依赖 vim.fn.executable / vim.filetype.add / vim.filetype.match，
-- ft 用独一无二的假扩展名避免污染其它测试）。

local T = MiniTest.new_set()
local eq = MiniTest.expect.equality

local function fresh()
	package.loaded["tools.lang_registry"] = nil
	return require("tools.lang_registry")
end

---@param fn function
---@param needle string 期望出现在 error message 里的片段
local function expect_error(fn, needle)
	local ok, err = pcall(fn)
	eq(ok, false)
	eq(tostring(err):find(needle, 1, true) ~= nil, true)
end

T["register + declared roundtrip keeps the spec verbatim"] = function()
	local R = fresh()
	R.register("promqlx", {
		ft = { extension = { promqlx = "promqlx" } },
		lsp = { promqlx_ls = { in_process = false } },
	})
	local d = R.declared()
	eq(d.promqlx.ft.extension.promqlx, "promqlx")
	eq(d.promqlx.lsp.promqlx_ls.in_process, false)
end

T["duplicate language fails loud"] = function()
	local R = fresh()
	R.register("go", {})
	expect_error(function() R.register("go", {}) end, 'duplicate language "go"')
end

T["unknown spec key fails loud (typo guard)"] = function()
	local R = fresh()
	expect_error(function() R.register("x", { fts = {} }) end, 'unknown spec key "fts"')
end

T["unknown lsp entry key fails loud"] = function()
	local R = fresh()
	expect_error(function() R.register("x", { lsp = { srv = { prob = "bin" } } }) end, 'unknown lsp key "prob"')
end

T["same server from two languages fails loud, names both"] = function()
	local R = fresh()
	R.register("a", { lsp = { shared_ls = {} } })
	expect_error(function() R.register("b", { lsp = { shared_ls = {} } }) end, 'already registered by "a"')
end

T["same ft key from two languages fails loud"] = function()
	local R = fresh()
	R.register("a", { ft = { extension = { zztestext = "aft" } } })
	expect_error(
		function() R.register("b", { ft = { extension = { zztestext = "bft" } } }) end,
		'extension "zztestext" already registered by "a"'
	)
end

T["unknown ft kind fails loud"] = function()
	local R = fresh()
	expect_error(function() R.register("x", { ft = { extensions = {} } }) end, 'unknown ft kind "extensions"')
end

T["invalid probe type fails loud"] = function()
	local R = fresh()
	expect_error(function() R.register("x", { lsp = { srv = { probe = 42 } } }) end, "must be string|string[]|function")
end

T["omitted probe enables unconditionally (external)"] = function()
	local R = fresh()
	R.register("x", { lsp = { always_ls = {} } })
	eq(R.enabled_lsp_servers(), { external = { "always_ls" }, in_process = {} })
end

T["string probe: executable hit enables, miss excludes"] = function()
	local R = fresh()
	R.register("x", { lsp = { hit_ls = { probe = "sh" }, miss_ls = { probe = "zz-no-such-bin" } } })
	eq(R.enabled_lsp_servers(), { external = { "hit_ls" }, in_process = {} })
end

T["list probe: any-of semantics"] = function()
	local R = fresh()
	R.register("x", {
		lsp = {
			any_ls = { probe = { "zz-no-such-bin", "sh" } },
			none_ls = { probe = { "zz-no-such-bin", "zz-also-missing" } },
		},
	})
	eq(R.enabled_lsp_servers(), { external = { "any_ls" }, in_process = {} })
end

T["function probe: return value decides"] = function()
	local R = fresh()
	R.register("x", {
		lsp = {
			yes_ls = { probe = function() return true end },
			no_ls = { probe = function() return false end },
		},
	})
	eq(R.enabled_lsp_servers(), { external = { "yes_ls" }, in_process = {} })
end

T["in_process servers are routed to their own list"] = function()
	local R = fresh()
	R.register("go", { lsp = { golangci_fixx = { in_process = true } } })
	eq(R.enabled_lsp_servers(), { external = {}, in_process = { "golangci_fixx" } })
end

T["enable order is sorted by server name (deterministic)"] = function()
	local R = fresh()
	R.register("b", { lsp = { zeta_ls = {} } })
	R.register("a", { lsp = { alpha_ls = {}, midd_ls = {} } })
	eq(R.enabled_lsp_servers().external, { "alpha_ls", "midd_ls", "zeta_ls" })
end

T["apply_ft merges languages into one vim.filetype.add"] = function()
	local R = fresh()
	R.register("a", { ft = { extension = { zzlangrega = "zzfta" } } })
	R.register("b", { ft = { filename = { ["zz.langreg.b"] = "zzftb" } } })
	R.apply_ft()
	eq(vim.filetype.match({ filename = "x.zzlangrega" }), "zzfta")
	eq(vim.filetype.match({ filename = "zz.langreg.b" }), "zzftb")
end

T["apply_ft with no ft declarations is a no-op"] = function()
	local R = fresh()
	R.register("x", { lsp = { srv = {} } })
	R.apply_ft() -- 不该 error；无 ft 声明时不调 vim.filetype.add
end

return T
