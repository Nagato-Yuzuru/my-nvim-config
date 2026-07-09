-- lua/tools/float_preview.lua 的边界测试：真实 buffer/window，零 mock。
-- 前身是手写 harness 的 tests/float_preview_spec.lua，行为清单原样迁入 mini.test。

local H = require("tests.helpers")
local child, hooks = H.new_child()

-- 每个 case 的 child 侧公共设施：模块引用 + 恒有效的浮窗几何 + 临时文件工厂。
local pre_restart = hooks.pre_case
hooks.pre_case = function()
	pre_restart()
	child.lua([[
		FP = require("tools.float_preview")
		-- 一个永远够大的居中几何，便于开真实浮窗。
		GEO = function()
			return {
				relative = "editor",
				width = 40,
				height = 10,
				row = 1,
				col = 1,
				style = "minimal",
				border = "rounded",
				noautocmd = true,
			}
		end
		function WRITE_TMP(name, lines)
			local path = vim.fn.tempname() .. "-" .. name
			assert(vim.fn.writefile(lines, path) == 0, "writefile failed: " .. path)
			return path
		end
	]])
end

local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

T["show(real file) fills a read-only scratch float"] = function()
	child.lua([[
		PATH = WRITE_TMP("hello.lua", { "local x = 1", "return x" })
		fp = FP.new({ geometry = GEO })
		SHOWN = fp:show(PATH)
		BUF = vim.api.nvim_win_get_buf(fp:win())
	]])
	eq(child.lua_get("SHOWN"), true)
	eq(child.lua_get("fp:is_open()"), true)
	eq(child.lua_get("vim.api.nvim_buf_get_lines(BUF, 0, -1, false)"), { "local x = 1", "return x" })
	eq(child.lua_get("vim.bo[BUF].modifiable"), false)
	eq(child.lua_get("vim.bo[BUF].buftype"), "nofile")
	eq(child.lua_get("vim.bo[BUF].bufhidden"), "wipe")
	eq(child.lua_get("vim.bo[BUF].filetype"), "lua")
	eq(child.lua_get("fp:key()"), child.lua_get("PATH"))
	child.lua("fp:close()")
	eq(child.lua_get("fp:is_open()"), false)
end

T["show(binary with NUL) returns false and stays closed"] = function()
	child.lua([[
		PATH = vim.fn.tempname() .. "-binary.bin"
		local f = assert(io.open(PATH, "wb"))
		f:write("ELF\0\0\0\1garbage\0more")
		f:close()
		fp = FP.new({ geometry = GEO })
		SHOWN = fp:show(PATH)
	]])
	eq(child.lua_get("SHOWN"), false)
	eq(child.lua_get("fp:is_open()"), false)
end

T["show(oversized > MAX_LINES) returns false and stays closed"] = function()
	child.lua([[
		local many = {}
		for i = 1, 30001 do
			many[i] = "line " .. i
		end
		PATH = WRITE_TMP("huge.txt", many)
		fp = FP.new({ geometry = GEO })
		SHOWN = fp:show(PATH)
	]])
	eq(child.lua_get("SHOWN"), false)
	eq(child.lua_get("fp:is_open()"), false)
end

T["show(exactly MAX_LINES) still opens (off-by-one boundary)"] = function()
	child.lua([[
		local many = {}
		for i = 1, 30000 do
			many[i] = "line " .. i
		end
		PATH = WRITE_TMP("max.txt", many)
		fp = FP.new({ geometry = GEO })
		SHOWN = fp:show(PATH)
	]])
	eq(child.lua_get("SHOWN"), true)
	eq(child.lua_get("fp:is_open()"), true)
end

T["same key: winid unchanged (dedup, no rebuild)"] = function()
	child.lua([[
		PATH = WRITE_TMP("dedup.txt", { "a", "b", "c" })
		fp = FP.new({ geometry = GEO })
		fp:show(PATH)
		WIN1 = fp:win()
		fp:show(PATH)
		WIN2 = fp:win()
	]])
	eq(child.lua_get("WIN1 ~= nil and WIN1 == WIN2"), true)
end

T["different key: window reused, buffer swapped"] = function()
	child.lua([[
		A = WRITE_TMP("a.txt", { "aaa" })
		B = WRITE_TMP("b.txt", { "bbb", "bbb" })
		fp = FP.new({ geometry = GEO })
		fp:show(A)
		WIN1, BUF1 = fp:win(), vim.api.nvim_win_get_buf(fp:win())
		fp:show(B)
		WIN2, BUF2 = fp:win(), vim.api.nvim_win_get_buf(fp:win())
	]])
	eq(child.lua_get("WIN1 == WIN2"), true)
	eq(child.lua_get("BUF1 ~= BUF2"), true)
	eq(child.lua_get("vim.api.nvim_buf_get_lines(BUF2, 0, -1, false)[1]"), "bbb")
	eq(child.lua_get("fp:key()"), child.lua_get("B"))
end

T["mute absorbs exactly one matching show_auto, then lets the next pass"] = function()
	child.lua([[
		A = WRITE_TMP("mute_a.txt", { "a" })
		B = WRITE_TMP("mute_b.txt", { "b" })
		fp = FP.new({ geometry = GEO, auto = true })
		fp:mute(A)
		ABSORBED = fp:show_auto(A)
		OPEN_AFTER_ABSORB = fp:is_open()
		PASSED = fp:show_auto(B)
	]])
	eq(child.lua_get("ABSORBED"), false)
	eq(child.lua_get("OPEN_AFTER_ABSORB"), false)
	eq(child.lua_get("PASSED"), true)
	eq(child.lua_get("fp:is_open()"), true)
end

T["mute only absorbs the matching key"] = function()
	child.lua([[
		A = WRITE_TMP("mute_a.txt", { "a" })
		B = WRITE_TMP("mute_b.txt", { "b" })
		fp = FP.new({ geometry = GEO, auto = true })
		fp:mute(A)
		PASSED_B = fp:show_auto(B)
	]])
	eq(child.lua_get("PASSED_B"), true)
	eq(child.lua_get("fp:is_open()"), true)
end

T["stale generation result is dropped, not applied"] = function()
	-- 自定义"异步" source：同步返回 content，但在 show(b) 之后手工用 a 捕获的
	-- 旧 gen 调内部 _apply，模拟晚到的旧异步结果。generation 门应丢弃它。
	child.lua([[
		B1 = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(B1, 0, -1, false, { "content A" })
		B2 = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(B2, 0, -1, false, { "content B" })
		fp = FP.new({
			geometry = GEO,
			source = function(req)
				CAPTURED_GEN = fp._gen -- 解析发起时的 gen
				return { buf = req.buf, key = req.key }
			end,
		})
		fp:show({ buf = B1, key = "a" })
		GEN_A = CAPTURED_GEN
		KEY_AFTER_A = fp:key()
		fp:show({ buf = B2, key = "b" })
		APPLIED = fp:_apply(GEN_A, { buf = B1, key = "a" })
	]])
	eq(child.lua_get("KEY_AFTER_A"), "a")
	eq(child.lua_get("APPLIED"), false)
	eq(child.lua_get("fp:key()"), "b")
end

T["double close is idempotent"] = function()
	child.lua([[
		PATH = WRITE_TMP("idem.txt", { "x" })
		fp = FP.new({ geometry = GEO })
		fp:show(PATH)
		fp:close()
	]])
	MiniTest.expect.no_error(function() child.lua("fp:close()") end)
	eq(child.lua_get("fp:is_open()"), false)
end

T["show_auto is gated by the auto flag"] = function()
	child.lua([[
		PATH = WRITE_TMP("gate.txt", { "y" })
		fp = FP.new({ geometry = GEO, auto = false })
		SHOWN_OFF = fp:show_auto(PATH)
		OPEN_OFF = fp:is_open()
		fp.auto = true
		SHOWN_ON = fp:show_auto(PATH)
	]])
	eq(child.lua_get("SHOWN_OFF"), false)
	eq(child.lua_get("OPEN_OFF"), false)
	eq(child.lua_get("SHOWN_ON"), true)
	eq(child.lua_get("fp:is_open()"), true)
end

T["toggle flips open/closed; toggle_auto flips and shows immediately"] = function()
	child.lua([[
		PATH = WRITE_TMP("toggle.txt", { "z" })
		fp = FP.new({ geometry = GEO })
		fp:toggle(PATH)
		OPEN1 = fp:is_open()
		fp:toggle(PATH)
		OPEN2 = fp:is_open()
		AUTO1 = fp:toggle_auto(PATH) -- false → true，且立即 show
		OPEN3 = fp:is_open()
		AUTO2 = fp:toggle_auto(PATH) -- true → false；关 auto 不主动关窗
	]])
	eq(child.lua_get("OPEN1"), true)
	eq(child.lua_get("OPEN2"), false)
	eq(child.lua_get("AUTO1"), true)
	eq(child.lua_get("OPEN3"), true)
	eq(child.lua_get("AUTO2"), false)
end

T["geometry returning nil closes the float (no-space semantics)"] = function()
	child.lua([[
		PATH = WRITE_TMP("nogeo.txt", { "q" })
		ALLOW = true
		fp = FP.new({
			geometry = function()
				if ALLOW then
					return GEO()
				end
				return nil
			end,
		})
		fp:show(PATH)
		OPEN1 = fp:is_open()
		ALLOW = false
		fp:show(PATH)
	]])
	eq(child.lua_get("OPEN1"), true)
	eq(child.lua_get("fp:is_open()"), false)
end

T["on_show fires per (re)build with controller, not on dedup"] = function()
	child.lua([[
		A = WRITE_TMP("os_a.txt", { "1" })
		B = WRITE_TMP("os_b.txt", { "2" })
		CALLS = 0
		fp = FP.new({
			geometry = GEO,
			on_show = function(_, self)
				CALLS = CALLS + 1
				LAST_IS_FP = (self == fp)
			end,
		})
		fp:show(A)
		CALLS_FIRST = CALLS
		fp:show(B) -- 换 key → 重建 → 再回调
		CALLS_REBUILD = CALLS
		fp:show(B) -- 同 key → 去重 → 不回调
	]])
	eq(child.lua_get("CALLS_FIRST"), 1)
	eq(child.lua_get("LAST_IS_FP"), true)
	eq(child.lua_get("CALLS_REBUILD"), 2)
	eq(child.lua_get("CALLS"), 2)
end

return T
