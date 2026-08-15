-- neotest 自定义 consumer 的逻辑主体,从 plugins/runtime/neotest.lua 的 config
-- 闭包提出的 tested seam(spec: tests/test_neotest_consumers.lua)。注册表与
-- 键位接线仍在插件 spec;本模块顶层不 require neotest / nio——运行期依赖注入
-- 或惰性 require,测试用假 client / 假 nt / vim 本体即可全覆盖。
--
-- ⚠ 私有 API 依赖清单(集中在此;上游改名只需改这里,别处不得再摸私有字段):
--   * client._state:update_results(adapter_id, results, partial)
--     —— neotest.client 的 `_` 前缀字段。partial=false 分支会把
--     _running[adapter_id][pos_id] 置 nil 并 emit RESULTS 事件,所有 consumer
--     (status / summary / pending)自动刷新。这是唯一能"合成 result 清
--     running 态"的入口:result 本只能由 adapter 上报,没有公共 API 能设;
--     `run.stop(pos)` 只发 SIGINT,进程已退出时是 no-op、不清 running。
--     整个 neotest v5+ 都是这布局,风险可控。换的是"能从卡死状态恢复"。

local M = {}

-- ============================================================================
-- "Drop stuck" —— 强制清掉卡在 running 态的 position。
-- ----------------------------------------------------------------------------
-- 触发场景:cargo 编译失败 / adapter 没解析出 libtest 输出(典型于 Rust 文件
-- 里有 panic 之外的 compile error,rustaceanvim 没把 cargo 非零退出翻译成
-- result)。表现是 summary 里某个 position 永远转圈——neotest 的状态机里
-- "编译失败"不是合法的 test status。
--
-- 解法:对每个卡住的 position 合成一个 failed result,经 update_results
-- (见顶部私有 API 清单)喂回去。
--
-- 为了能拿到 client 引用,把 M.capture 注册成一个空 consumer——consumer 被
-- setup 调用是必经路径,唯一作用是捕获 client 到 module-local,之后
-- drop_stuck() 能从 keymap 调到。
-- ============================================================================
local captured_client

---注册进 neotest.config.consumers 的空 consumer(插件 spec 里名字叫 drop)。
function M.capture(client) captured_client = client end

---列出并强清所有卡在 running 态的 position(<leader>tS 的实现)。
---@param nt table|nil  neotest 模块;测试注入假对象,生产走默认 require
function M.drop_stuck(nt)
	if not captured_client then
		vim.notify("neotest: client not captured yet (run setup / a test first)", vim.log.levels.WARN)
		return
	end
	nt = nt or require("neotest")

	local total = 0
	local labels = {}

	for _, adapter_id in ipairs(nt.state.adapter_ids()) do
		local tree = nt.state.positions(adapter_id)
		if tree then
			local synth = {}
			for _, node in tree:iter_nodes() do
				local pos = node:data()
				-- 三种 position 都可能卡:
				--   * test       —— 单测被 update_running 后没回 result
				--   * namespace  —— mod / describe / suite 级聚合卡
				--   * file       —— `<leader>tT` 整文件跑常被锁在这一层
				--                   (rustaceanvim 发 update_running 给 file id,
				--                   cargo 编译失败时 result 永远不回)
				-- 排除 dir:dir 是合成节点,自己没 running 状态。
				if pos.type ~= "dir" and captured_client:is_running(pos.id, { adapter = adapter_id }) then
					total = total + 1
					table.insert(labels, ("  • [%s] %s"):format(pos.type, pos.name or pos.id))
					synth[pos.id] = {
						status = "failed",
						short = "neotest: dropped (stuck without result — likely compile error or no libtest output)",
						errors = {},
					}
					-- 顺手对真在跑的进程发一下 stop——已退出就 no-op
					pcall(function() nt.run.stop(pos.id) end)
				end
			end
			if next(synth) then
				captured_client._state:update_results(adapter_id, synth, false)
			end
		end
	end

	if total == 0 then
		vim.notify("neotest: nothing stuck in running", vim.log.levels.INFO)
	else
		vim.notify(
			("neotest: dropped %d stuck position(s):\n%s"):format(total, table.concat(labels, "\n")),
			vim.log.levels.WARN
		)
	end
end

-- ============================================================================
-- Pending consumer:在被发现但还没跑过的 test 行放一个 "pending" 标志。
-- ----------------------------------------------------------------------------
-- 官方 status consumer (lua/neotest/consumers/status.lua) 只为
-- passed/failed/running/skipped 定义 sign——既没有 result 也不在跑的位置直接
-- return(line 26),所以"已发现未跑"的测试在 gutter 上没有任何视觉提示。
--
-- 这里复刻官方的事件结构(discover_positions / run / results /
-- test_file_focused),但只为"无 result 且不在跑"的 test 位置放标志。
-- priority = 100 远低于官方的 1000——测试一开始跑,status consumer 立刻盖上
-- running/passed/failed sign;同时自己的 run/results listener 也会在
-- render_files 里 unplace 旧的 pending 再重算,不会双重显示。sign group 与
-- 官方完全独立,互不干扰。
-- ============================================================================

---挂 pending 渲染流水线到 client.listeners。
---
---vx 是 vim 形状的调用面({ fn = …, api = … })。生产传 require("nio"):
---neotest 的 client.listeners.* 在 nvim-nio 协程里跑("fast context"),直接
---调 vim.fn.bufnr 之类会触发 E5560,nio.fn / nio.api 内部 yield 到主循环再
---resume,是官方 consumer(status / diagnostic)的标准做法。测试传 vim 本体,
---同步执行、直接断言 sign。
---@param client table  neotest client(listeners / get_results / get_position / is_running)
---@param vx table  { fn: table, api: table }
function M.attach_pending(client, vx)
	local sign_group = "neotest-pending"
	local sign_name = "neotest_pending"
	vx.fn.sign_define(sign_name, {
		text = "◌",
		texthl = "DiagnosticHint",
	})

	local function render_files(adapter_id, files)
		for _, file_path in pairs(files) do
			local bufnr = vx.fn.bufnr(file_path)
			if bufnr > 0 and vx.fn.buflisted(bufnr) ~= 0 and vx.api.nvim_buf_is_valid(bufnr) then
				local results = client:get_results(adapter_id)
				local tree = client:get_position(file_path, { adapter = adapter_id })
				if tree then
					vx.fn.sign_unplace(sign_group, { buffer = bufnr })
					local line_count = vx.api.nvim_buf_line_count(bufnr)
					for _, node in tree:iter_nodes() do
						local pos = node:data()
						if pos.range and pos.type == "test" then
							local has_result = results[pos.id] ~= nil
							local is_running = client:is_running(pos.id, { adapter = adapter_id })
							if not has_result and not is_running then
								local lnum = pos.range[1] + 1
								if lnum <= line_count then
									vx.fn.sign_place(0, sign_group, sign_name, bufnr, {
										lnum = lnum,
										priority = 100,
									})
								end
							end
						end
					end
				end
			end
		end
	end

	client.listeners.discover_positions = function(adapter_id, tree)
		if tree:data().type == "file" then
			render_files(adapter_id, { tree:data().id })
		end
	end

	client.listeners.run = function(adapter_id, _, position_ids)
		local files = {}
		for _, pos_id in pairs(position_ids) do
			local node = client:get_position(pos_id, { adapter = adapter_id })
			if node and node:data().type ~= "dir" then
				files[node:data().path] = true
			end
		end
		render_files(adapter_id, vim.tbl_keys(files))
	end

	client.listeners.results = function(adapter_id, results)
		local files = {}
		for pos_id, _ in pairs(results) do
			local node = client:get_position(pos_id, { adapter = adapter_id })
			if node and node:data().type ~= "dir" then
				files[node:data().path] = true
			end
		end
		render_files(adapter_id, vim.tbl_keys(files))
	end

	client.listeners.test_file_focused = function(adapter_id, file_path) render_files(adapter_id, { file_path }) end
end

---注册进 neotest.config.consumers 的形状(插件 spec 里名字叫 pending)。
function M.pending(client) M.attach_pending(client, require("nio")) end

return M
