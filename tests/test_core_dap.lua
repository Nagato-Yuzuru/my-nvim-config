-- lua/core/dap.lua 的 prompt_args 行为测试（setup/ensure_mason 是纯接线，
-- 不在此测）。vim.fn.input 是不属于我们的边界，换成记录 prompt/default 并
-- 返回预设答案的桩。

local H = require("tests.helpers")
local child, hooks = H.new_child()

local pre_restart = hooks.pre_case
hooks.pre_case = function()
	pre_restart()
	child.lua([[
		CD = require("core.dap")
		CALLS, ANSWER = {}, ""
		vim.fn.input = function(prompt, default)
			table.insert(CALLS, { prompt = prompt, default = default })
			return ANSWER
		end
	]])
end

local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

T["按空白切分输入，返回具体参数列表"] = function()
	child.lua([[ANSWER = "-num 30 -v"]])
	eq(child.lua_get([[CD.prompt_args("k")()]]), { "-num", "30", "-v" })
	eq(child.lua_get("CALLS[1].prompt"), "Program args: ")
end

T["空输入返回空列表（= 无参数启动）"] = function()
	child.lua([[ANSWER = ""]])
	eq(child.lua_get([[CD.prompt_args("k")()]]), {})
end

T["首尾/连续空白不产生空参数"] = function()
	child.lua([[ANSWER = "  a   b  "]])
	eq(child.lua_get([[CD.prompt_args("k")()]]), { "a", "b" })
end

T["会话内记忆：第二次弹出时预填上次输入，且按 key 隔离"] = function()
	child.lua([[
		FN_A, FN_B = CD.prompt_args("a"), CD.prompt_args("b")
		ANSWER = "-num 7"
		FN_A()
		ANSWER = ""
		FN_A()
		FN_B()
	]])
	eq(child.lua_get("CALLS[1].default"), "") -- key a 首次：无预填
	eq(child.lua_get("CALLS[2].default"), "-num 7") -- key a 二次：预填上次
	eq(child.lua_get("CALLS[3].default"), "") -- key b 不吃 key a 的记忆
	-- 空输入也会更新记忆（用户清空 = 之后默认无参数）
	child.lua([[FN_A()]])
	eq(child.lua_get("CALLS[4].default"), "")
end

return T
