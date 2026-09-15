-- ftplugin/go.lua 的 insert `,` 映射：普通 `,` 必须进 redo buffer（`.` 寄存器），
-- 否则 dot-repeat 与 multicursor.nvim 的插入回放（按 `.` 寄存器重放到其他光标）
-- 都会丢逗号；命中单返回值类型时仍包成 `(T, |)`。

local H = require("tests.helpers")
local child, hooks = H.new_child()

local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

local function setbuf(lines)
	child.api.nvim_buf_set_lines(0, 0, -1, false, lines)
	child.bo.filetype = "go"
	-- 生产侧由 treesitter 高亮负责解析；测试环境无高亮，get_node 前手动建树。
	child.lua('vim.treesitter.get_parser(0, "go"):parse()')
end
local function buf() return child.api.nvim_buf_get_lines(0, 0, -1, false) end

T["plain comma keeps the redo buffer intact"] = function()
	setbuf({ "package main", "", "func main() {", "\tf(1", "\tf(2", "}" })
	child.api.nvim_win_set_cursor(0, { 4, 0 })
	child.type_keys("A", "x", ",", "y", "<Esc>")
	eq(child.fn.getreg("."), "x,y")
	child.type_keys("j", ".")
	eq(buf()[4], "\tf(1x,y")
	eq(buf()[5], "\tf(2x,y")
end

T["comma on a single result type wraps it"] = function()
	setbuf({ "package main", "", "func g() string {", "}" })
	child.api.nvim_win_set_cursor(0, { 3, 14 })
	child.type_keys("a", ",", "error", "<Esc>")
	eq(buf()[3], "func g() (string, error) {")
end

return T
