-- lua/tools/neotest_consumers.lua 的行为测试。
--
-- drop_stuck:注入假 client / 假 neotest(nt 参数),vim.notify 换成记录器;
-- 断言合成 result 的具体内容、update_results 的 partial=false、stop 调用序列
-- 与 notify 文案。tree/node 都是最小假对象(data + iter_nodes)。
--
-- attach_pending:vx 传 vim 本体(生产传 nio,fn/api 同名代理),listener
-- 同步执行,对真 buffer 直接断言 sign 的行号 / priority / 定义。

local H = require("tests.helpers")
local child, hooks = H.new_child()

local pre_restart = hooks.pre_case
hooks.pre_case = function()
	pre_restart()
	child.lua([[
		NC = require("tools.neotest_consumers")
		NOTES = {}
		vim.notify = function(msg, level) table.insert(NOTES, { msg = msg, level = level }) end
		-- 最小假 tree:iter_nodes 按序吐 { data() } 节点;tree:data() 返回第一
		-- 个位置(neotest 的 file 根节点约定)
		function TREE(positions)
			return {
				data = function() return positions[1] end,
				iter_nodes = function()
					local i = 0
					return function()
						i = i + 1
						if positions[i] then
							local pos = positions[i]
							return i, { data = function() return pos end }
						end
					end
				end,
			}
		end
	]])
end

local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

-- ===== drop_stuck =====

local function setup_drop()
	child.lua([[
		UPDATES, STOPS, RUNNING = {}, {}, {}
		CLIENT = {
			is_running = function(_, pos_id) return RUNNING[pos_id] == true end,
			_state = {
				update_results = function(_, adapter_id, results, partial)
					table.insert(UPDATES, { adapter_id = adapter_id, results = results, partial = partial })
				end,
			},
		}
		ADAPTER_IDS, TREES = {}, {}
		NT = {
			state = {
				adapter_ids = function() return ADAPTER_IDS end,
				positions = function(id) return TREES[id] end,
			},
			run = { stop = function(pos_id) table.insert(STOPS, pos_id) end },
		}
	]])
end

T["drop_stuck: warns when client not captured, touches nothing"] = function()
	setup_drop()
	child.lua([[NC.drop_stuck(NT)]])
	eq(child.lua_get("#NOTES"), 1)
	eq(child.lua_get("NOTES[1].msg"), "neotest: client not captured yet (run setup / a test first)")
	eq(child.lua_get("NOTES[1].level"), vim.log.levels.WARN)
	eq(child.lua_get("#UPDATES"), 0)
	eq(child.lua_get("#STOPS"), 0)
end

T["drop_stuck: nothing stuck notifies INFO, no update_results"] = function()
	setup_drop()
	child.lua([[
		NC.capture(CLIENT)
		ADAPTER_IDS = { "go" }
		TREES.go = TREE({ { id = "t1", type = "test", name = "TestFoo" } })
		NC.drop_stuck(NT)
	]])
	eq(child.lua_get("NOTES[1].msg"), "neotest: nothing stuck in running")
	eq(child.lua_get("NOTES[1].level"), vim.log.levels.INFO)
	eq(child.lua_get("#UPDATES"), 0)
	eq(child.lua_get("#STOPS"), 0)
end

T["drop_stuck: synthesizes failed results for stuck file/namespace/test, never dir"] = function()
	setup_drop()
	child.lua([[
		NC.capture(CLIENT)
		ADAPTER_IDS = { "go" }
		TREES.go = TREE({
			{ id = "d1", type = "dir", name = "pkg" },
			{ id = "f1", type = "file", name = "a_test.go" },
			{ id = "n1", type = "namespace", name = "TestSuite" },
			{ id = "t1", type = "test", name = "TestFoo" },
			{ id = "t2", type = "test", name = "TestBar" },
		})
		-- d1 故意也置 running:dir 是合成节点,必须被排除
		RUNNING = { d1 = true, f1 = true, n1 = true, t1 = true }
		NC.drop_stuck(NT)
	]])
	eq(child.lua_get("#UPDATES"), 1)
	eq(child.lua_get("UPDATES[1].adapter_id"), "go")
	eq(child.lua_get("UPDATES[1].partial"), false)
	eq(child.lua_get("vim.tbl_count(UPDATES[1].results)"), 3)
	eq(child.lua_get("UPDATES[1].results.d1 == nil"), true)
	eq(child.lua_get("UPDATES[1].results.t2 == nil"), true)
	eq(child.lua_get("UPDATES[1].results.t1.status"), "failed")
	eq(
		child.lua_get("UPDATES[1].results.t1.short"),
		"neotest: dropped (stuck without result — likely compile error or no libtest output)"
	)
	eq(child.lua_get("#UPDATES[1].results.t1.errors"), 0)
	eq(child.lua_get("STOPS"), { "f1", "n1", "t1" })
	eq(
		child.lua_get("NOTES[1].msg"),
		"neotest: dropped 3 stuck position(s):\n"
			.. "  • [file] a_test.go\n"
			.. "  • [namespace] TestSuite\n"
			.. "  • [test] TestFoo"
	)
	eq(child.lua_get("NOTES[1].level"), vim.log.levels.WARN)
end

T["drop_stuck: label falls back to pos.id when name is absent"] = function()
	setup_drop()
	child.lua([[
		NC.capture(CLIENT)
		ADAPTER_IDS = { "py" }
		TREES.py = TREE({ { id = "file::test_x", type = "test" } })
		RUNNING = { ["file::test_x"] = true }
		NC.drop_stuck(NT)
	]])
	eq(child.lua_get("NOTES[1].msg"), "neotest: dropped 1 stuck position(s):\n  • [test] file::test_x")
end

T["drop_stuck: per-adapter update, adapters without stuck or without tree untouched"] = function()
	setup_drop()
	child.lua([[
		NC.capture(CLIENT)
		-- ghost 无 tree(positions 返回 nil):容忍跳过
		ADAPTER_IDS = { "go", "py", "ghost" }
		TREES.go = TREE({ { id = "g1", type = "test", name = "G" } })
		TREES.py = TREE({ { id = "p1", type = "test", name = "P" } })
		RUNNING = { g1 = true }
		NC.drop_stuck(NT)
	]])
	eq(child.lua_get("#UPDATES"), 1)
	eq(child.lua_get("UPDATES[1].adapter_id"), "go")
	eq(child.lua_get("STOPS"), { "g1" })
	eq(child.lua_get("NOTES[1].msg"), "neotest: dropped 1 stuck position(s):\n  • [test] G")
end

-- ===== attach_pending =====

local function setup_pending()
	child.lua([[
		RUNNING, RESULTS, POSITIONS = {}, {}, {}
		PCLIENT = {
			listeners = {},
			get_results = function() return RESULTS end,
			get_position = function(_, id) return POSITIONS[id] end,
			is_running = function(_, pos_id) return RUNNING[pos_id] == true end,
		}
		NC.attach_pending(PCLIENT, vim) -- 测试面:vim 本体,同步执行
		FILE = vim.fn.tempname() .. "_x.py"
		vim.fn.writefile({ "l1", "l2", "l3", "l4", "l5" }, FILE)
		vim.cmd.edit(FILE)
		BUF = vim.api.nvim_get_current_buf()
		-- file 树:file 根 + test 子节点(range[1] = 0-based 行号)
		function FILE_TREE(tests)
			local positions = { { id = FILE, type = "file", path = FILE } }
			for _, t in ipairs(tests) do
				positions[#positions + 1] =
					{ id = t.id, type = "test", path = FILE, range = { t.lnum0, 0, t.lnum0, 10 } }
			end
			return TREE(positions)
		end
		function SIGNS()
			local placed = vim.fn.sign_getplaced(BUF, { group = "neotest-pending" })[1].signs
			local lnums = {}
			for _, s in ipairs(placed) do
				lnums[#lnums + 1] = s.lnum
			end
			table.sort(lnums)
			return lnums
		end
	]])
end

T["attach_pending: wires all four listeners"] = function()
	setup_pending()
	for _, l in ipairs({ "discover_positions", "run", "results", "test_file_focused" }) do
		eq(child.lua_get(('type(PCLIENT.listeners["%s"])'):format(l)), "function")
	end
end

T["attach_pending: signs only never-run tests; out-of-range rows skipped"] = function()
	setup_pending()
	child.lua([[
		RESULTS["t2"] = { status = "passed" }
		RUNNING["t3"] = true
		POSITIONS[FILE] = FILE_TREE({
			{ id = "t1", lnum0 = 1 },
			{ id = "t2", lnum0 = 2 }, -- 已有 result:不放
			{ id = "t3", lnum0 = 3 }, -- 在跑:不放
			{ id = "t99", lnum0 = 99 }, -- 行号越界:跳过不报错
		})
		PCLIENT.listeners.discover_positions("go", POSITIONS[FILE])
	]])
	eq(child.lua_get("SIGNS()"), { 2 })
	-- sign text 由 vim 补齐到 2 cell:单宽 ◌ 存储为 "◌ "
	eq(child.lua_get([[vim.fn.sign_getdefined("neotest_pending")[1].text]]), "◌ ")
	eq(child.lua_get([[vim.fn.sign_getplaced(BUF, { group = "neotest-pending" })[1].signs[1].priority]]), 100)
end

T["attach_pending: namespace nodes never get pending signs"] = function()
	setup_pending()
	child.lua([[
		POSITIONS[FILE] = TREE({
			{ id = FILE, type = "file", path = FILE },
			{ id = "ns", type = "namespace", path = FILE, range = { 0, 0, 4, 0 } },
		})
		PCLIENT.listeners.discover_positions("go", POSITIONS[FILE])
	]])
	eq(child.lua_get("SIGNS()"), {})
end

T["attach_pending: run listener drops the now-running test's sign"] = function()
	setup_pending()
	child.lua([[
		POSITIONS[FILE] = FILE_TREE({ { id = "t1", lnum0 = 1 }, { id = "t2", lnum0 = 2 } })
		PCLIENT.listeners.discover_positions("go", POSITIONS[FILE])
	]])
	eq(child.lua_get("SIGNS()"), { 2, 3 })
	child.lua([[
		RUNNING["t1"] = true
		POSITIONS["t1"] = { data = function() return { type = "test", path = FILE } end }
		PCLIENT.listeners.run("go", nil, { "t1" })
	]])
	eq(child.lua_get("SIGNS()"), { 3 })
end

T["attach_pending: results listener re-renders from fresh results"] = function()
	setup_pending()
	child.lua([[
		POSITIONS[FILE] = FILE_TREE({ { id = "t1", lnum0 = 1 }, { id = "t2", lnum0 = 2 } })
		PCLIENT.listeners.discover_positions("go", POSITIONS[FILE])
		RESULTS["t1"] = { status = "failed" }
		POSITIONS["t1"] = { data = function() return { type = "test", path = FILE } end }
		PCLIENT.listeners.results("go", { t1 = { status = "failed" } })
	]])
	eq(child.lua_get("SIGNS()"), { 3 })
end

T["attach_pending: dir-only run event triggers no re-render"] = function()
	setup_pending()
	child.lua([[
		POSITIONS[FILE] = FILE_TREE({ { id = "t1", lnum0 = 1 }, { id = "t2", lnum0 = 2 } })
		PCLIENT.listeners.discover_positions("go", POSITIONS[FILE])
		-- 若发生重渲染,t1(已置 running)的 sign 会消失——留着即证明没渲染
		RUNNING["t1"] = true
		POSITIONS["d1"] = { data = function() return { type = "dir", path = "/some/dir" } end }
		PCLIENT.listeners.run("go", nil, { "d1" })
	]])
	eq(child.lua_get("SIGNS()"), { 2, 3 })
end

T["attach_pending: test_file_focused re-renders the file"] = function()
	setup_pending()
	child.lua([[
		POSITIONS[FILE] = FILE_TREE({ { id = "t1", lnum0 = 0 } })
		PCLIENT.listeners.test_file_focused("go", FILE)
	]])
	eq(child.lua_get("SIGNS()"), { 1 })
end

T["attach_pending: unopened or unlisted files are skipped without error"] = function()
	setup_pending()
	child.lua([[
		OTHER = vim.fn.tempname() .. "_ghost.py" -- 从未打开的文件
		POSITIONS[OTHER] = TREE({ { id = OTHER, type = "file", path = OTHER } })
		OK1 = pcall(PCLIENT.listeners.discover_positions, "go", POSITIONS[OTHER])
		POSITIONS[FILE] = FILE_TREE({ { id = "t1", lnum0 = 1 } })
		PCLIENT.listeners.discover_positions("go", POSITIONS[FILE])
		SIGNS_BEFORE = SIGNS()
		-- 摘掉 listed 标记后再触发:跳过(不重算,不报错),旧 sign 原样留着
		vim.bo[BUF].buflisted = false
		RUNNING["t1"] = true
		OK2 = pcall(PCLIENT.listeners.discover_positions, "go", POSITIONS[FILE])
	]])
	eq(child.lua_get("OK1"), true)
	eq(child.lua_get("SIGNS_BEFORE"), { 2 })
	eq(child.lua_get("OK2"), true)
	eq(child.lua_get("SIGNS()"), { 2 })
end

return T
