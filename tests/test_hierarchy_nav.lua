-- lua/tools/hierarchy_nav.lua 的 classify 测试：真 go parser（.deps 钉 v0.25.0），
-- 光标放在各类声明的名字上，断言方向判定。LSP 请求接线不在此测。

local H = require("tests.helpers")
local child, hooks = H.new_child()

local pre_restart = hooks.pre_case
hooks.pre_case = function()
	pre_restart()
	child.lua([[
		GI = require("tools.hierarchy_nav")
		vim.api.nvim_buf_set_lines(0, 0, -1, true, {
			"package x",                                  -- 0
			"type Shape interface{ Area() int }",         -- 1
			"type Sq struct{}",                           -- 2
			"func (Sq) Area() int { v := 1; return v }",  -- 3
			"type Fn func()",                             -- 4
			"type Alias = Shape",                         -- 5
			"type ID int",                                -- 6
		})
		vim.treesitter.get_parser(0, "go"):parse()
		function AT(row, col)
			return GI.classify(vim.treesitter.get_node({ bufnr = 0, pos = { row, col } }))
		end
	]])
end

local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

T["接口类型 → abstract"] = function() eq(child.lua_get("AT(1, 5)"), "abstract") end
T["接口方法 → abstract"] = function() eq(child.lua_get("AT(1, 22)"), "abstract") end
T["struct → concrete"] = function() eq(child.lua_get("AT(2, 5)"), "concrete") end
T["具名非接口类型 → concrete"] = function() eq(child.lua_get("AT(6, 5)"), "concrete") end
T["具体方法 → concrete"] = function() eq(child.lua_get("AT(3, 10)"), "concrete") end
T["具体方法体内的局部变量 → nil（不误判为方法）"] = function()
	eq(child.lua_get("AT(3, 23)"), vim.NIL)
end
T["函数类型 → nil（gopls 向下找可赋值函数）"] = function() eq(child.lua_get("AT(4, 5)"), vim.NIL) end
T["类型别名 → nil"] = function() eq(child.lua_get("AT(5, 5)"), vim.NIL) end

return T
