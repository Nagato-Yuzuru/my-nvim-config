-- lua/tools/debug_hydra.lua 的行为测试。
--
-- hydra.nvim / nvim-dap 都是第三方边界，用 package.preload 注入假实现：
-- 假 Hydra 记录构造 spec 并模拟真插件的 on_enter/on_exit 回调时机
-- （activate → on_enter，exit → on_exit）；假 dap 记录动作调用序列。
-- 断言激活/退出的 guard 语义、head 键位表的具体内容、缺插件时的降级。

local H = require("tests.helpers")
local child, hooks = H.new_child()

local pre_restart = hooks.pre_case
hooks.pre_case = function()
	pre_restart()
	child.lua([[
		NOTES = {}
		vim.notify = function(msg, level) table.insert(NOTES, { msg = msg, level = level }) end

		DAP_CALLS = {}
		package.preload["dap"] = function()
			local dap = {}
			for _, name in ipairs({
				"step_over", "step_into", "step_out", "continue",
				"run_to_cursor", "down", "up", "focus_frame",
			}) do
				dap[name] = function() table.insert(DAP_CALLS, name) end
			end
			return dap
		end

		-- 假 Hydra：建模 pin commit 8c4a9f6 的 pink 形状 —— 实例带 .layer；
		-- activate() 转发 layer:activate()（触发 on_enter）；实例自己的
		-- exit() 复刻上游 bug（跑 on_exit 但**不**触 layer teardown），
		-- layer:exit() 才是完整路径。被测模块必须走 layer:exit()。
		SPECS, INSTANCES = {}, {}
		function INSTALL_HYDRA_STUB()
			package.preload["hydra"] = function()
				return function(spec)
					table.insert(SPECS, spec)
					local inst = { activations = 0, exits = 0 }
					inst.layer = { activations = 0, exits = 0 }
					function inst.layer:activate()
						self.activations = self.activations + 1
						if spec.config and spec.config.on_enter then spec.config.on_enter() end
					end
					function inst.layer:exit()
						self.exits = self.exits + 1
						if spec.config and spec.config.on_exit then spec.config.on_exit() end
					end
					function inst:activate()
						self.activations = self.activations + 1
						self.layer:activate()
					end
					function inst:exit()
						self.exits = self.exits + 1
						if spec.config and spec.config.on_exit then spec.config.on_exit() end
					end
					table.insert(INSTANCES, inst)
					return inst
				end
			end
		end
	]])
end

local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

local function load_with_stub()
	child.lua([[
		INSTALL_HYDRA_STUB()
		DH = require("tools.debug_hydra")
	]])
end

T["activate: 首次调用构造 bodyless pink hydra 并激活一次"] = function()
	load_with_stub()
	child.lua([[DH.activate()]])
	eq(child.lua_get("#SPECS"), 1)
	eq(child.lua_get("SPECS[1].body"), vim.NIL) -- bodyless：session 外零键位占用
	eq(child.lua_get("SPECS[1].config.color"), "pink")
	eq(child.lua_get("SPECS[1].config.hint.type"), "window")
	eq(child.lua_get("INSTANCES[1].activations"), 1)
	eq(child.lua_get("INSTANCES[1].layer.activations"), 1)
end

T["activate: 已激活时重复触发是 no-op（event_stopped 每步都来）"] = function()
	load_with_stub()
	child.lua([[DH.activate() DH.activate() DH.activate()]])
	eq(child.lua_get("#SPECS"), 1)
	eq(child.lua_get("INSTANCES[1].activations"), 1)
end

T["activate: 非 normal 模式跳过，连构造都不发生"] = function()
	load_with_stub()
	child.type_keys("i") -- 插入态（如正往 REPL 敲字时断点停住）
	eq(child.lua_get("vim.fn.mode()"), "i")
	child.lua([[DH.activate()]])
	eq(child.lua_get("#SPECS"), 0)
	eq(child.lua_get("#INSTANCES"), 0)
end

T["activate: exit 后可重入，实例复用不重复构造"] = function()
	load_with_stub()
	child.lua([[DH.activate() DH.exit() DH.activate()]])
	eq(child.lua_get("#SPECS"), 1)
	eq(child.lua_get("INSTANCES[1].activations"), 2)
	eq(child.lua_get("INSTANCES[1].layer.exits"), 1)
end

T["exit: 未构造时是 no-op，不报错不构造"] = function()
	load_with_stub()
	child.lua([[DH.exit()]])
	eq(child.lua_get("#SPECS"), 0)
	eq(child.lua_get("#NOTES"), 0)
end

T["exit: 走 layer 完整 teardown 而非上游 bug 的 instance:exit，且不重复下发"] = function()
	load_with_stub()
	child.lua([[DH.activate() DH.exit() DH.exit()]])
	-- layer:exit() 恰好一次；instance:exit()（上游泄漏路径）零次
	eq(child.lua_get("INSTANCES[1].layer.exits"), 1)
	eq(child.lua_get("INSTANCES[1].exits"), 0)
end

T["heads: 裸键别名表与 dap 动作一一对应，全部 nowait"] = function()
	load_with_stub()
	child.lua([[DH.activate()]])
	-- lhs → 预期 dap 调用；<Esc> 是纯 exit head（rhs = nil）
	local expected = {
		n = "step_over",
		s = "step_into",
		f = "step_out",
		c = "continue",
		u = "run_to_cursor",
		J = "down",
		K = "up",
		["."] = "focus_frame",
	}
	-- 注意 [=[ 长括号：内容里 `head[1]]` 的 `]]` 会提前终结普通 [[ 字符串
	local heads = child.lua_get([=[(function()
		local out = {}
		for _, head in ipairs(SPECS[1].heads) do
			out[head[1]] = {
				has_rhs = head[2] ~= nil,
				nowait = head[3] and head[3].nowait or false,
				exit = head[3] and head[3].exit or false,
			}
		end
		return out
	end)()]=])
	for lhs in pairs(expected) do
		eq(heads[lhs].has_rhs, true)
		eq(heads[lhs].nowait, true)
	end
	eq(heads["<Esc>"].has_rhs, false)
	eq(heads["<Esc>"].exit, true)
	eq(vim.tbl_count(heads), 9) -- 8 动作 + Esc，多一个少一个都算坏
	-- 逐个调 rhs，断言打到 dap 的具体动作
	for lhs, dap_fn in pairs(expected) do
		child.lua(([[DAP_CALLS = {}
			for _, head in ipairs(SPECS[1].heads) do
				if head[1] == %q then head[2]() end
			end]]):format(lhs))
		eq(child.lua_get("DAP_CALLS"), { dap_fn })
	end
end

T["降级: hydra.nvim 缺失时 warn 恰好一次，后续 activate 静默 no-op"] = function()
	-- 不装 hydra 桩：minimal_init 的 rtp 里没有真 hydra.nvim，require 自然失败
	child.lua([[DH = require("tools.debug_hydra")]])
	child.lua([[DH.activate() DH.activate()]])
	eq(child.lua_get("#NOTES"), 1)
	eq(child.lua_get("NOTES[1].msg"), "debug_hydra: hydra.nvim not available — falling back to `,*` keys")
	eq(child.lua_get("NOTES[1].level"), vim.log.levels.WARN)
	child.lua([[DH.exit()]]) -- 降级态 exit 也必须安全
	eq(child.lua_get("#NOTES"), 1)
end

return T
