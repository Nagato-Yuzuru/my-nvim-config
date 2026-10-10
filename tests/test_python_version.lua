-- tools/python_version.lua 的解析与 before_init 注入。restart() 依赖真实 client，
-- 不在这里测。

local T = MiniTest.new_set()
local eq = MiniTest.expect.equality

local function fresh()
	package.loaded["tools.python_version"] = nil
	return require("tools.python_version")
end

T["normalize accepts 3.x and py3x forms"] = function()
	local pv = fresh()
	eq(pv.normalize("3.10"), "3.10")
	eq(pv.normalize(" py39 "), "3.9")
	eq(pv.normalize("py313"), "3.13")
end

T["normalize rejects other shapes"] = function()
	local pv = fresh()
	for _, bad in ipairs({ "", "3", "2.7", "3.10.1", "py2", "python3.10", "3.x" }) do
		local v, err = pv.normalize(bad)
		eq(v, nil)
		eq(type(err), "string")
	end
end

T["parse_help_versions reads both ruff and ty help shapes"] = function()
	local pv = fresh()
	eq(pv.parse_help_versions("--target-version\n  [possible values: py37, py39, py315]\n"), { "3.7", "3.9", "3.15" })
	eq(
		pv.parse_help_versions("  [possible values: 3.14, 3.15]\n  [possible values: linux, darwin]"),
		{ "3.14", "3.15" }
	)
	eq(pv.parse_help_versions("no list here"), {})
end

T["no override leaves ruff params and ty settings untouched"] = function()
	local pv = fresh()
	local params = { initializationOptions = { settings = { organizeImports = true } } }
	local ruff_cfg = { init_options = params.initializationOptions }
	pv.ruff_before_init(params, ruff_cfg)
	eq(params.initializationOptions, { settings = { organizeImports = true } })

	local ty_cfg = { settings = {} }
	pv.ty_before_init({}, ty_cfg)
	eq(ty_cfg.settings, {})
end

T["ruff gets target-version merged into existing init_options"] = function()
	local pv = fresh()
	pv.set("3.10")
	local shared = { settings = { organizeImports = true } }
	local params = { initializationOptions = shared }
	local cfg = { init_options = shared }
	pv.ruff_before_init(params, cfg)
	eq(params.initializationOptions, {
		settings = { organizeImports = true, configuration = { ["target-version"] = "py310" } },
	})
	eq(cfg.init_options, params.initializationOptions)
	eq(shared, { settings = { organizeImports = true } })
end

T["ty settings are written in place (client.settings holds the same ref)"] = function()
	local pv = fresh()
	pv.set("3.9")
	local settings = {}
	local cfg = { settings = settings }
	pv.ty_before_init({}, cfg)
	eq(cfg.settings, settings)
	eq(settings, { ty = { configuration = { environment = { ["python-version"] = "3.9" } } } })
end

T["clearing the override stops injection for the next client"] = function()
	local pv = fresh()
	pv.set("3.11")
	pv.set(nil)
	local cfg = { settings = {} }
	pv.ty_before_init({}, cfg)
	eq(cfg.settings, {})
	eq(pv.get(), nil)
end

return T
