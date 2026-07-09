-- lua/tools/scheme_toolchain.lua 的 M.parse_raco_show 测试：纯字符串解析，
-- 无需 child 隔离，直接在 collector 进程里跑。fixture 就是函数 doc 注释里的
-- ASCII 示例（raco pkg show 的真实输出形态）。

local parse = require("tools.scheme_toolchain").parse_raco_show

local T = MiniTest.new_set()
local eq = MiniTest.expect.equality

-- doc 注释里的完整示例：安装行带 auto-install 标记 + header + [none] 孤行
local FIXTURE = table.concat({
	"Installation-wide:",
	" Package[*=auto]   Checksum   Source",
	" base*             a7c0b66... catalog base",
	' User-specific for installation "8.12":',
	" [none]",
}, "\n")

T["installed row with auto-install marker matches (marker stripped)"] = function() eq(parse(FIXTURE, "base"), true) end

T["installed row without marker matches"] = function()
	local out = "User-specific:\n racket-langserver   abcd123   catalog racket-langserver\n"
	eq(parse(out, "racket-langserver"), true)
end

T["absent package returns false"] = function() eq(parse(FIXTURE, "fmt"), false) end

T["[none] orphan row never matches a package"] = function() eq(parse(FIXTURE, "[none]"), false) end

T["header row does not collide with real package names"] = function()
	-- header 首列是字面量 "Package[*=auto]"，真实包名（如 "Package"）不会撞上
	eq(parse(FIXTURE, "Package"), false)
	eq(parse(FIXTURE, "Checksum"), false)
end

T["unindented section headings are ignored"] = function() eq(parse(FIXTURE, "Installation-wide:"), false) end

T["package name prefix does not match a longer installed name"] = function()
	local out = " fmt-extra   abc   catalog fmt-extra\n"
	eq(parse(out, "fmt"), false)
end

T["empty output returns false"] = function() eq(parse("", "base"), false) end

T["package present in a later scope still matches"] = function()
	local out = table.concat({
		"Installation-wide:",
		" [none]",
		'User-specific for installation "8.12":',
		" Package[*=auto]   Checksum   Source",
		" fmt               deadbee... catalog fmt",
	}, "\n")
	eq(parse(out, "fmt"), true)
end

return T
