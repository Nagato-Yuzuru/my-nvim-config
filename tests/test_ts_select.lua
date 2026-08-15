-- lua/tools/ts_select.lua 的行为测试。
--
-- select_or_abort:26c075d 回归——textobject 无命中时 operator 必须中止。
-- select_fn 注入同形 no-op 模拟上游"无命中 = 静默返回、不动 mode",无需加载
-- nvim-treesitter-textobjects;对照组用"无 abort 的裸 select"钉住旧 bug 的
-- 失败形态(c 无端进 insert),证明 harness 抓得住这类回归。
--
-- expand/shrink:真 python parser(.deps 按 minimal_init 钉 v0.25.0,期望值
-- 稳定)。覆盖:同 range 包装节点跳过、根节点 ecol==0 行尾贴齐、normal 起手
-- 栈重置、per-buffer 栈独立(gv 续扩)、空 buffer。

local H = require("tests.helpers")
local child, hooks = H.new_child()

local pre_restart = hooks.pre_case
hooks.pre_case = function()
	pre_restart()
	child.lua([[
		TS = require("tools.ts_select")
		vim.o.hidden = true -- 多 buffer 用例要在 unnamed+modified 间切换
		-- 当前 charwise visual 选区文本;非 visual 返回 "MODE:<mode>"
		function REGION()
			local m = vim.api.nvim_get_mode().mode
			if m ~= "v" then
				return "MODE:" .. m
			end
			return table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = "v" }), "\n")
		end
		-- 当前 buffer 填 python 内容并完成解析
		function PYBUF(lines)
			vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
			vim.bo.filetype = "python"
			vim.treesitter.get_parser(0, "python"):parse()
		end
	]])
end

local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

-- ===== select_or_abort =====

T["select_or_abort: miss aborts the operator (26c075d regression)"] = function()
	child.lua([[vim.keymap.set({ "x", "o" }, "al", TS.select_or_abort(function() end, "@loop.outer"))]])
	child.api.nvim_buf_set_lines(0, 0, -1, true, { "hello world" })
	child.type_keys("cal")
	eq(child.api.nvim_get_mode().mode, "n")
	eq(child.api.nvim_buf_get_lines(0, 0, -1, true), { "hello world" })
end

T["select_or_abort: miss makes `d` a no-op"] = function()
	child.lua([[vim.keymap.set({ "x", "o" }, "al", TS.select_or_abort(function() end, "@loop.outer"))]])
	child.api.nvim_buf_set_lines(0, 0, -1, true, { "hello world" })
	child.type_keys("dal")
	eq(child.api.nvim_get_mode().mode, "n")
	eq(child.api.nvim_buf_get_lines(0, 0, -1, true), { "hello world" })
end

-- 对照组:同样的无命中,不带 abort(= 26c075d 之前的旧接线)。钉住失败形态,
-- 也证明上面的回归用例在旧代码上会红。
T["control: same miss without the abort drops `c` into insert (old bug shape)"] = function()
	child.lua([[vim.keymap.set({ "x", "o" }, "al", function() end)]])
	child.api.nvim_buf_set_lines(0, 0, -1, true, { "hello world" })
	child.type_keys("cal")
	eq(child.api.nvim_get_mode().mode, "i")
end

T["select_or_abort: hit lets the operator act on the selection"] = function()
	child.lua([[
		vim.keymap.set({ "x", "o" }, "al", TS.select_or_abort(function()
			vim.cmd("normal! viw") -- 模拟命中:上游同样以进入 visual 表达选区
		end, "@loop.outer"))
	]])
	child.api.nvim_buf_set_lines(0, 0, -1, true, { "hello world" })
	child.type_keys("dal")
	eq(child.api.nvim_buf_get_lines(0, 0, -1, true), { " world" })
	eq(child.api.nvim_get_mode().mode, "n")
end

T["select_or_abort: miss in visual mode leaves visual alone (no abort)"] = function()
	child.lua([[vim.keymap.set({ "x", "o" }, "al", TS.select_or_abort(function() end, "@loop.outer"))]])
	child.api.nvim_buf_set_lines(0, 0, -1, true, { "hello world" })
	child.type_keys("v", "al")
	eq(child.api.nvim_get_mode().mode, "v")
end

-- ===== incremental selection =====

-- 各用例共用 buffer `{ "def f():", "    x = 1 + 2", "", "y = 3" }`。
-- 光标在 `1` 上时的节点链(实测):integer → binary_operator → assignment →
-- [expression_statement → block 同 range,跳过] → function_definition →
-- module (0,0)-(4,0)。

T["expand: walks up, skipping same-range wrapper nodes"] = function()
	child.lua([[PYBUF({ "def f():", "    x = 1 + 2", "", "y = 3" })]])
	child.api.nvim_win_set_cursor(0, { 2, 8 }) -- `1` 上
	local expect = {
		"1",
		"1 + 2",
		"x = 1 + 2",
		-- expression_statement / block 与 assignment 同 range:一步跳到函数
		"def f():\n    x = 1 + 2",
	}
	for _, region in ipairs(expect) do
		child.lua("TS.expand()")
		eq(child.lua_get("REGION()"), region)
	end
end

T["expand: root ending at col 0 snaps to end of last line"] = function()
	child.lua([[PYBUF({ "def f():", "    x = 1 + 2", "", "y = 3" })]])
	child.api.nvim_win_set_cursor(0, { 2, 8 })
	for _ = 1, 5 do
		child.lua("TS.expand()")
	end
	-- module 的 range 是 (0,0)-(4,0):终点贴齐到末行 "y = 3" 行尾
	eq(child.lua_get("REGION()"), "def f():\n    x = 1 + 2\n\ny = 3")
end

-- 现状钉死(回归护栏,非设计背书):到顶后 next_larger 为 nil,`or` 回落到
-- get_node()——光标此时在选区起点,于是"从头再包一层"而不是 no-op。
T["expand past root: falls back to the node under cursor (pinned)"] = function()
	child.lua([[PYBUF({ "def f():", "    x = 1 + 2", "", "y = 3" })]])
	child.api.nvim_win_set_cursor(0, { 2, 8 })
	for _ = 1, 6 do
		child.lua("TS.expand()")
	end
	eq(child.lua_get("REGION()"), "def f():\n    x = 1 + 2")
end

T["shrink: walks back down and stops at the innermost node"] = function()
	child.lua([[PYBUF({ "def f():", "    x = 1 + 2", "", "y = 3" })]])
	child.api.nvim_win_set_cursor(0, { 2, 8 })
	for _ = 1, 5 do
		child.lua("TS.expand()")
	end
	local expect = { "def f():\n    x = 1 + 2", "x = 1 + 2", "1 + 2", "1" }
	for _, region in ipairs(expect) do
		child.lua("TS.shrink()")
		eq(child.lua_get("REGION()"), region)
	end
	-- 栈底(#stack <= 1):再缩是 no-op,停在最内层
	child.lua("TS.shrink()")
	eq(child.lua_get("REGION()"), "1")
end

T["expand: starting from normal mode resets the stack"] = function()
	child.lua([[PYBUF({ "def f():", "    x = 1 + 2", "", "y = 3" })]])
	child.api.nvim_win_set_cursor(0, { 2, 8 })
	child.lua("TS.expand()")
	child.lua("TS.expand()")
	eq(child.lua_get("REGION()"), "1 + 2")
	child.type_keys("<Esc>")
	child.api.nvim_win_set_cursor(0, { 4, 0 }) -- `y` 上
	child.lua("TS.expand()")
	-- 栈已重置:从 `y` 的最内层起,而不是接着 binary_operator 往上
	eq(child.lua_get("REGION()"), "y")
end

T["expand: stacks are per-buffer, resumable via gv"] = function()
	child.lua([[PYBUF({ "def f():", "    x = 1 + 2", "", "y = 3" })]])
	child.api.nvim_win_set_cursor(0, { 2, 8 })
	child.lua("TS.expand()")
	child.lua("TS.expand()")
	eq(child.lua_get("REGION()"), "1 + 2")
	child.type_keys("<Esc>")
	child.lua([[
		A = vim.api.nvim_get_current_buf()
		vim.cmd.enew()
		PYBUF({ "z = 9" })
	]])
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.lua("TS.expand()")
	eq(child.lua_get("REGION()"), "z")
	child.type_keys("<Esc>")
	child.lua([[vim.api.nvim_set_current_buf(A)]])
	child.type_keys("gv") -- 恢复 A 的上一个 visual 选区
	eq(child.lua_get("REGION()"), "1 + 2")
	child.lua("TS.expand()")
	-- 从 A 自己的栈顶(binary_operator)继续,不是 B 的 —— 全局单栈会在
	-- 这里拿 B 的节点在 A 里定位选区
	eq(child.lua_get("REGION()"), "x = 1 + 2")
end

T["shrink: no-op without a prior expand"] = function()
	child.lua([[PYBUF({ "y = 3" })]])
	child.lua("TS.shrink()")
	eq(child.lua_get("REGION()"), "MODE:n")
end

T["expand: empty buffer does not error"] = function()
	child.lua([[
		PYBUF({ "" })
		OK = pcall(TS.expand)
	]])
	eq(child.lua_get("OK"), true)
	eq(child.lua_get("vim.api.nvim_get_mode().mode"), "v")
end

return T
