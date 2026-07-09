-- lua/tools/wrap.lua 的边界测试：真实 buffer + 真实 treesitter parser + 真实
-- deleft（minimal_init 自举）。wrap 走无 UI 接缝 M.wrap(name)；pick 的异步
-- 失效防护（finding #2/#4）用 stub 的 vim.ui.select 复现——那是计划里唯一
-- 允许 stub 的交互边界。5 个"对抗 review finding"各有命名用例。

local H = require("tests.helpers")
local child, hooks = H.new_child()

local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

local function setbuf(lines, ft)
	child.api.nvim_buf_set_lines(0, 0, -1, false, lines)
	child.bo.filetype = ft
end
local function buf() return child.api.nvim_buf_get_lines(0, 0, -1, false) end
local function wrap(name) return child.lua_get(("require('tools.wrap').wrap(%q)"):format(name)) end
local function unwrap() child.lua("require('tools.wrap').unwrap()") end

-- ============================================================ wrap：正例
T["wrap"] = MiniTest.new_set()

T["wrap"]["linewise: common indent becomes base, block hangs"] = function()
	setbuf({ "\tlocal a = 1", "\tlocal b = 2" }, "lua")
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("V", "j")
	eq(wrap("if … then"), true)
	eq(buf(), { "\tif condition then", "\t\tlocal a = 1", "\t\tlocal b = 2", "\tend" })
end

T["wrap"]["charwise single-line: in-place replace at byte column"] = function()
	setbuf({ "\tdoIt(x)" }, "go")
	child.api.nvim_win_set_cursor(0, { 1, 1 })
	child.type_keys("v", "$")
	eq(wrap("if err := …; err != nil"), true)
	eq(buf(), { "\tif err := doIt(x); err != nil {", "\t\treturn err", "\t}" })
end

T["wrap"]["charwise multi-line: first line kept, rest dedented then hung"] = function()
	setbuf({ "local x = foo(1,", "\t2)" }, "lua")
	child.api.nvim_win_set_cursor(0, { 1, 10 })
	child.type_keys("v", "j", "$")
	eq(wrap("pcall(function() … end)"), true)
	eq(buf(), { "local x = local ok, err = pcall(function()", "\tfoo(1,", "\t2)", "end)" })
end

T["wrap"]["python: expandtab buffer renders \\t as spaces"] = function()
	setbuf({ "x = 1" }, "python")
	child.type_keys("V")
	eq(wrap("if"), true)
	eq(buf(), { "if condition:", "    x = 1" })
end

T["wrap"]["normal mode without selection wraps current line"] = function()
	setbuf({ "print(9)" }, "lua")
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	eq(wrap("if … then"), true)
	eq(buf(), { "if condition then", "\tprint(9)", "end" })
end

T["wrap"]["escapes $ and backslash in selection (byte-identical after wrap)"] = function()
	setbuf({ [[local s = "$HOME \ ${x}"]] }, "lua")
	child.type_keys("V")
	eq(wrap("do … end"), true)
	eq(buf(), { "do", [[	local s = "$HOME \ ${x}"]], "end" })
end

-- finding #5：空行不垫 hang，垫了就是纯空白行
T["wrap"]["finding#5: empty selection line gets no hang padding"] = function()
	setbuf({ "local a = 1", "", "local b = 2" }, "lua")
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("V", "2j")
	eq(wrap("do … end"), true)
	eq(buf(), { "do", "\tlocal a = 1", "", "\tlocal b = 2", "end" })
end

T["wrap"]["mixed tab/space indent: only true common prefix is stripped"] = function()
	setbuf({ "\t  a()", "\t b()" }, "lua")
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("V", "j")
	eq(wrap("do … end"), true)
	eq(buf(), { "\t do", "\t \t a()", "\t \tb()", "\t end" })
end

-- ============================================================ wrap：反例/边界
T["wrap"]["blockwise selection is rejected, buffer untouched"] = function()
	setbuf({ "aa", "bb" }, "lua")
	child.type_keys("<C-v>", "j")
	eq(wrap("do … end"), false)
	eq(buf(), { "aa", "bb" })
end

T["wrap"]["unknown template name is a no-op returning false"] = function()
	setbuf({ "x = 1" }, "lua")
	child.type_keys("V")
	eq(wrap("does-not-exist"), false)
	eq(buf(), { "x = 1" })
end

T["wrap"]["filetype without templates returns false"] = function()
	setbuf({ "plain prose" }, "text")
	child.type_keys("V")
	eq(wrap("if"), false)
	eq(buf(), { "plain prose" })
end

-- finding #3：模板记号缺失/多于一个是编码错误，必须在动 buffer 之前炸
T["wrap"]["finding#3: template without token errors before editing"] = function()
	setbuf({ "x = 1" }, "lua")
	child.lua([[table.insert(require("tools.wrap").templates.lua, { name = "bad0", body = "if $1 then\nend" })]])
	child.type_keys("V")
	MiniTest.expect.error(function() child.lua([[require("tools.wrap").wrap("bad0")]]) end, "exactly one")
	eq(buf(), { "x = 1" })
end

T["wrap"]["finding#3: template with two tokens errors before editing"] = function()
	setbuf({ "x = 1" }, "lua")
	child.lua(
		[[table.insert(require("tools.wrap").templates.lua, { name = "bad2", body = "$SELECTION$\n$SELECTION$" })]]
	)
	child.type_keys("V")
	MiniTest.expect.error(function() child.lua([[require("tools.wrap").wrap("bad2")]]) end, "exactly one")
	eq(buf(), { "x = 1" })
end

T["wrap"]["single empty line still wraps"] = function()
	setbuf({ "" }, "lua")
	child.type_keys("V")
	eq(wrap("do … end"), true)
	-- 中间的 "\t" 是模板自带的块缩进落在空选区上（非 finding#5 的 hang 垫行）；
	-- 退化用例，接受现状
	eq(buf(), { "do", "\t", "end" })
end

-- 每个内置模板的展开不留残渣：$SELECTION$ 被替换、tabstop 全部展开、选区
-- 两行原文都在。逐模板精确断言由上面的代表性用例承担。
T["wrap"]["every template"] = MiniTest.new_set({
	parametrize = (function()
		local params = {}
		for ft, tpls in pairs(require("tools.wrap").templates) do
			for _, tpl in ipairs(tpls) do
				params[#params + 1] = { ft, tpl.name }
			end
		end
		table.sort(params, function(a, b) return a[1] .. a[2] < b[1] .. b[2] end)
		return params
	end)(),
})

T["wrap"]["every template"]["expands without residue"] = function(ft, name)
	setbuf({ "alpha()", "beta()" }, ft)
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("V", "j")
	eq(wrap(name), true)
	local joined = table.concat(buf(), "\n")
	eq(joined:find("$SELECTION$", 1, true), nil)
	eq(joined:find("${", 1, true), nil)
	eq(joined:find("alpha()", 1, true) ~= nil, true)
	eq(joined:find("beta()", 1, true) ~= nil, true)
end

-- ============================================================ pick：异步失效防护
T["pick"] = MiniTest.new_set()

-- finding #2/#4：picker 挂起期间 buffer 被改 → 陈旧行列号不得写回
T["pick"]["finding#2/#4: buffer changed while picking aborts, nothing applied"] = function()
	setbuf({ "local a = 1" }, "lua")
	-- stub 出"异步 picker"：把回调存起来，pick() 先返回
	child.lua([[
		vim.ui.select = function(items, _, on_choice)
			_G.PICK_ITEMS, _G.PICK_CB = items, on_choice
		end
	]])
	child.type_keys("V")
	child.lua([[require("tools.wrap").pick()]])
	child.lua([[vim.api.nvim_buf_set_lines(0, 0, 0, false, { "-- injected while picking" })]])
	child.lua([[_G.PICK_CB(_G.PICK_ITEMS[1])]])
	eq(buf(), { "-- injected while picking", "local a = 1" })
end

T["pick"]["finding#2/#4: source window closed while picking aborts"] = function()
	setbuf({ "local a = 1" }, "lua")
	child.lua([[
		vim.ui.select = function(items, _, on_choice)
			_G.PICK_ITEMS, _G.PICK_CB = items, on_choice
		end
	]])
	child.type_keys("V")
	child.lua([[
		SRC_BUF = vim.api.nvim_get_current_buf()
		require("tools.wrap").pick()
		local src_win = vim.api.nvim_get_current_win()
		vim.cmd("new") -- 第二个窗口顶住，关掉源窗口
		vim.api.nvim_win_close(src_win, true)
	]])
	MiniTest.expect.no_error(function() child.lua([[_G.PICK_CB(_G.PICK_ITEMS[1])]]) end)
	eq(child.lua_get("vim.api.nvim_buf_get_lines(SRC_BUF, 0, -1, false)"), { "local a = 1" })
end

-- ============================================================ unwrap
T["unwrap"] = MiniTest.new_set()

T["unwrap"]["lua if: cursor in body strips the shell (deleft path)"] = function()
	setbuf({ "if cond then", "\tprint(1)", "\tprint(2)", "end" }, "lua")
	child.api.nvim_win_set_cursor(0, { 2, 1 })
	unwrap()
	eq(buf(), { "print(1)", "print(2)" })
end

T["unwrap"]["lua for: strips loop shell"] = function()
	setbuf({ "for i = 1, 3 do", "\twork(i)", "end" }, "lua")
	child.api.nvim_win_set_cursor(0, { 2, 1 })
	unwrap()
	eq(buf(), { "work(i)" })
end

T["unwrap"]["go: nearest enclosing block only (inner if)"] = function()
	setbuf({ "func main() {", "\tif x {", "\t\tcall()", "\t}", "}" }, "go")
	child.api.nvim_win_set_cursor(0, { 3, 2 })
	unwrap()
	eq(buf(), { "func main() {", "\tcall()", "}" })
end

T["unwrap"]["python if/elif/else: cursor branch survives (elif)"] = function()
	setbuf({ "if a:", "    x = 1", "elif b:", "    x = 2", "else:", "    x = 3" }, "python")
	child.api.nvim_win_set_cursor(0, { 4, 4 })
	unwrap()
	eq(buf(), { "x = 2" })
end

T["unwrap"]["python: cursor on construct header keeps the main branch"] = function()
	setbuf({ "if a:", "    x = 1", "elif b:", "    x = 2", "else:", "    x = 3" }, "python")
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	unwrap()
	eq(buf(), { "x = 1" })
end

T["unwrap"]["python try: finally always survives alongside cursor branch"] = function()
	setbuf({ "try:", "    a()", "except E as e:", "    b()", "finally:", "    c()" }, "python")
	child.api.nvim_win_set_cursor(0, { 2, 4 })
	unwrap()
	eq(buf(), { "a()", "c()" })
end

T["unwrap"]["python try: cursor in except keeps handler + finally"] = function()
	setbuf({ "try:", "    a()", "except E as e:", "    b()", "finally:", "    c()" }, "python")
	child.api.nvim_win_set_cursor(0, { 4, 4 })
	unwrap()
	eq(buf(), { "b()", "c()" })
end

-- finding #1：多行非块节点（return 表 / 多行调用）不是包裹构造，剥它就是毁代码
T["unwrap"]["finding#1: lua multi-line return table is not a wrapper"] = function()
	setbuf({ "return {", "\tx = 1,", "}" }, "lua")
	child.api.nvim_win_set_cursor(0, { 2, 1 })
	unwrap()
	eq(buf(), { "return {", "\tx = 1,", "}" })
end

T["unwrap"]["finding#1: python multi-line call is not a wrapper"] = function()
	setbuf({ "result = foo(", "    1,", "    2,", ")" }, "python")
	child.api.nvim_win_set_cursor(0, { 2, 4 })
	unwrap()
	eq(buf(), { "result = foo(", "    1,", "    2,", ")" })
end

T["unwrap"]["single-line construct is not a wrapper"] = function()
	setbuf({ "if cond then print(1) end" }, "lua")
	child.api.nvim_win_set_cursor(0, { 1, 15 })
	unwrap()
	eq(buf(), { "if cond then print(1) end" })
end

T["unwrap"]["top-level flat statement: no enclosing block, buffer untouched"] = function()
	setbuf({ "x = 1" }, "python")
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	unwrap()
	eq(buf(), { "x = 1" })
end

return T
