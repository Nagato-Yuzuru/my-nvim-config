-- Headless boundary tests for lua/tools/float_preview.lua.
-- Run: nvim -l tests/float_preview_spec.lua
--
-- 真实 buffer/window,零 mock。每个用例打 PASS/FAIL;任一失败 os.exit(1)。
-- 无外部依赖(不 require snacks / neominimap)。

-- nvim -l 下 package.path 不含本仓 lua/,手动加。
local here = debug.getinfo(1, "S").source:sub(2):gsub("/tests/float_preview_spec.lua$", "")
package.path = here .. "/lua/?.lua;" .. here .. "/lua/?/init.lua;" .. package.path

local FP = require("tools.float_preview")

local failures = 0
local total = 0

---@param name string
---@param cond boolean
---@param detail? string
local function check(name, cond, detail)
	total = total + 1
	if cond then
		io.write("PASS  " .. name .. "\n")
	else
		failures = failures + 1
		io.write("FAIL  " .. name .. (detail and ("  -- " .. detail) or "") .. "\n")
	end
end

-- 一个永远够大的居中几何,便于开真实浮窗。
local function big_geometry()
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

-- 写一个临时文件,返回绝对路径。
---@param name string
---@param lines string[]
---@return string
local function write_tmp(name, lines)
	local path = vim.fn.tempname() .. "-" .. name
	assert(vim.fn.writefile(lines, path) == 0, "writefile failed: " .. path)
	return path
end

-- ========================================================================
-- 1. show(真实文件) → 只读 scratch,行数 / filetype 正确
-- ========================================================================
do
	local path = write_tmp("hello.lua", { "local x = 1", "return x" })
	local fp = FP.new({ geometry = big_geometry })
	local shown = fp:show(path)
	check("show(real file) returns true", shown == true)
	check("show(real file) opens a valid float", fp:is_open() == true)

	local buf = vim.api.nvim_win_get_buf(fp:win())
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	check("scratch has correct line count", #lines == 2, "got " .. #lines)
	check("scratch line 1 content", lines[1] == "local x = 1", lines[1])
	check("scratch is not modifiable (read-only)", vim.bo[buf].modifiable == false)
	check("scratch buftype is nofile", vim.bo[buf].buftype == "nofile")
	check("scratch bufhidden is wipe", vim.bo[buf].bufhidden == "wipe")
	check("filetype detected as lua", vim.bo[buf].filetype == "lua", vim.bo[buf].filetype)
	check("key() equals the file path", fp:key() == path)

	fp:close()
	check("close hides the float", fp:is_open() == false)
end

-- ========================================================================
-- 2. 二进制文件(含 NUL) → 返回 false 且关闭
-- ========================================================================
do
	local path = vim.fn.tempname() .. "-binary.bin"
	local f = assert(io.open(path, "wb"))
	f:write("ELF\0\0\0\1garbage\0more")
	f:close()

	local fp = FP.new({ geometry = big_geometry })
	local shown = fp:show(path)
	check("show(binary) returns false", shown == false)
	check("show(binary) leaves float closed", fp:is_open() == false)
end

-- ========================================================================
-- 3. 超限文件(> 30000 行) → 返回 false 且关闭
-- ========================================================================
do
	local many = {}
	for i = 1, 30001 do
		many[i] = "line " .. i
	end
	local path = write_tmp("huge.txt", many)

	local fp = FP.new({ geometry = big_geometry })
	local shown = fp:show(path)
	check("show(oversized > MAX_LINES) returns false", shown == false)
	check("show(oversized) leaves float closed", fp:is_open() == false)
end

-- ========================================================================
-- 4. 相同 key 连续 show → winid 不变(去重,不重建窗口)
-- ========================================================================
do
	local path = write_tmp("dedup.txt", { "a", "b", "c" })
	local fp = FP.new({ geometry = big_geometry })
	fp:show(path)
	local win1 = fp:win()
	fp:show(path) -- 同 key
	local win2 = fp:win()
	check("same key: winid unchanged (dedup)", win1 == win2 and win1 ~= nil, tostring(win1) .. " vs " .. tostring(win2))
	fp:close()
end

-- ========================================================================
-- 5. 不同 key → buffer 被换(swap),窗口复用
-- ========================================================================
do
	local a = write_tmp("a.txt", { "aaa" })
	local b = write_tmp("b.txt", { "bbb", "bbb" })
	local fp = FP.new({ geometry = big_geometry })
	fp:show(a)
	local win1 = fp:win()
	local buf1 = vim.api.nvim_win_get_buf(win1)
	fp:show(b)
	local win2 = fp:win()
	local buf2 = vim.api.nvim_win_get_buf(win2)
	check("different key: window reused (same winid)", win1 == win2, tostring(win1) .. " vs " .. tostring(win2))
	check("different key: buffer swapped", buf1 ~= buf2)
	check("different key: shows new file's content", vim.api.nvim_buf_get_lines(buf2, 0, -1, false)[1] == "bbb")
	check("key() reflects the new file", fp:key() == b)
	fp:close()
end

-- ========================================================================
-- 6. mute 恰好吸收一个 show_auto,随后放行下一个
-- ========================================================================
do
	local a = write_tmp("mute_a.txt", { "a" })
	local bb = write_tmp("mute_b.txt", { "b" })
	local fp = FP.new({ geometry = big_geometry, auto = true })

	fp:mute(a)
	local absorbed = fp:show_auto(a) -- 被吸收
	check("mute absorbs the matching show_auto", absorbed == false)
	check("mute: float stays closed after absorbed show_auto", fp:is_open() == false)

	local passed = fp:show_auto(bb) -- 下一个放行
	check("mute is one-shot: next show_auto passes", passed == true)
	check("mute: next show_auto opens the float", fp:is_open() == true)
	fp:close()

	-- mute 只挡"匹配 key"的:mute(a) 后来个 b,应放行且清掉 mute。
	fp:mute(a)
	local passed_b = fp:show_auto(bb)
	check("mute only absorbs the matching key", passed_b == true)
	fp:close()
end

-- ========================================================================
-- 7. stale generation 被丢弃:show(a) → show(b) → 补投 a 的旧 gen 结果
-- ========================================================================
do
	-- 自定义"异步" source:同步返回 content,但测试在 show(b) 之后手工用 a 捕获
	-- 的旧 gen 调内部 _apply,模拟晚到的旧异步结果。generation 门应丢弃它。
	local buf_a = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf_a, 0, -1, false, { "content A" })
	local buf_b = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf_b, 0, -1, false, { "content B" })

	local captured_gen
	local fp -- 前置声明:source closure 要引用它,不能等 local 赋值完成
	fp = FP.new({
		geometry = big_geometry,
		source = function(req)
			captured_gen = fp._gen -- 解析发起时的 gen
			return { buf = req.buf, key = req.key }
		end,
	})

	fp:show({ buf = buf_a, key = "a" })
	local gen_a = captured_gen
	check("stale: show(a) opens float showing a", fp:key() == "a")

	fp:show({ buf = buf_b, key = "b" })
	check("stale: show(b) swaps to b", fp:key() == "b")

	-- 补投 a 的晚到结果,携带旧 gen_a → 必须被丢弃。
	local applied = fp:_apply(gen_a, { buf = buf_a, key = "a" })
	check("stale generation apply is dropped (returns false)", applied == false)
	check("stale: float still shows b (not clobbered by late a)", fp:key() == "b")

	fp:close()
	vim.api.nvim_buf_delete(buf_a, { force = true })
	vim.api.nvim_buf_delete(buf_b, { force = true })
end

-- ========================================================================
-- 8. close 幂等(二次 close 不报错)
-- ========================================================================
do
	local path = write_tmp("idem.txt", { "x" })
	local fp = FP.new({ geometry = big_geometry })
	fp:show(path)
	fp:close()
	local ok = pcall(function() fp:close() end)
	check("double close does not error", ok == true)
	check("double close leaves float closed", fp:is_open() == false)
end

-- ========================================================================
-- 9. show_auto 受 auto 门控
-- ========================================================================
do
	local path = write_tmp("gate.txt", { "y" })
	local fp = FP.new({ geometry = big_geometry, auto = false })
	local shown = fp:show_auto(path)
	check("show_auto with auto=false is a no-op", shown == false)
	check("show_auto with auto=false leaves float closed", fp:is_open() == false)

	fp.auto = true
	local shown2 = fp:show_auto(path)
	check("show_auto with auto=true shows", shown2 == true)
	check("show_auto with auto=true opens float", fp:is_open() == true)
	fp:close()
end

-- ========================================================================
-- 10. toggle 开/关;toggle_auto 翻转并在开启时立即刷
-- ========================================================================
do
	local path = write_tmp("toggle.txt", { "z" })
	local fp = FP.new({ geometry = big_geometry })
	fp:toggle(path)
	check("toggle from closed → opens", fp:is_open() == true)
	fp:toggle(path)
	check("toggle from open → closes", fp:is_open() == false)

	-- toggle_auto:auto 初始 false → 翻成 true 且立即 show。
	local now = fp:toggle_auto(path)
	check("toggle_auto returns new auto state (true)", now == true)
	check("toggle_auto on enable shows immediately", fp:is_open() == true)
	local now2 = fp:toggle_auto(path)
	check("toggle_auto returns new auto state (false)", now2 == false)
	-- 关 auto 不主动关窗(只是停止跟随)。
	fp:close()
end

-- ========================================================================
-- 11. geometry 返回 nil → 关闭(空间不足语义)
-- ========================================================================
do
	local path = write_tmp("nogeo.txt", { "q" })
	local allow = { v = true }
	local fp = FP.new({
		geometry = function() return allow.v and big_geometry() or nil end,
	})
	fp:show(path)
	check("geometry non-nil: float opens", fp:is_open() == true)
	allow.v = false
	fp:show(path) -- 现在 geometry 返回 nil
	check("geometry nil: float closes", fp:is_open() == false)
end

-- ========================================================================
-- 12. on_show 每次 (重)建后回调;source=nil 用缺省 scratch 管线
-- ========================================================================
do
	local a = write_tmp("os_a.txt", { "1" })
	local b = write_tmp("os_b.txt", { "2" })
	local calls = 0
	local last_self
	local fp = FP.new({
		geometry = big_geometry,
		on_show = function(_, self)
			calls = calls + 1
			last_self = self
		end,
	})
	fp:show(a)
	check("on_show fires on first build", calls == 1)
	check("on_show receives the controller as self", last_self == fp)
	fp:show(b) -- 换 key → 重建 → 再回调
	check("on_show fires again on rebuild (new key)", calls == 2)
	fp:show(b) -- 同 key → 去重 → 不回调
	check("on_show does NOT fire on dedup (same key)", calls == 2)
	fp:close()
end

-- ========================================================================
io.write(string.format("\n%d/%d checks passed\n", total - failures, total))
if failures > 0 then
	os.exit(1)
end
