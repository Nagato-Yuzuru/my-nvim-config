-- neotest — 测试 runner，跨语言统一 UX
--
-- 键位（<leader>t* 命名空间 + `[t`/`]t` 导航）：
--   <leader>tt   run nearest test
--   <leader>tT   run all tests in file
--   <leader>tl   run last test
--   <leader>td   debug nearest test (走 DAP)
--   <leader>tA   run nearest with args (picker: 按 ft 给 preset + custom)
--   <leader>ts   toggle summary panel
--   <leader>to   show output for nearest
--   <leader>tO   toggle output panel
--   <leader>tS   stop running tests
--   <leader>tw   toggle watch mode
--   <leader>tn   jump to NEXT failed test (neotest.jump, 仅失败)
--   <leader>tp   jump to PREV failed test (同上)
--
-- 诊断流的刻意隔离：
--   neotest 默认会把失败推到 vim.diagnostic —— 会和 LSP / nvim-lint 的
--   [d/]d 混在一起。这里显式 `diagnostic = { enabled = false }` 关掉。
--   测试失败的导航走 <leader>tn/tp（neotest.jump.next/.prev），和 lint/LSP
--   诊断彻底分开，互不污染。
--
-- 注：原想用 ]t/[t 走 vim "bracket 导航"惯例，但 `todo-comments.nvim` 已经
-- 占了那两个键（业界 TODO 注释跳转约定），避让，落回 <leader>t{n,p}。
--
-- IdeaVim 的 <leader>nt (GotoTest) 在 nvim 端不实现 —— neotest 没有 native 的
-- "跳到测试文件"语义，CLAUDE.md 里的保守判断对 Python/Rust 成立；Go/TS 的
-- convention 虽然清晰，但依赖 LSP + 符号查找已经够用，不额外做 go-to 启发式。

-- <leader>tA: IDE 式 "run with extra args" picker。按 filetype 给最常用的
-- preset，加一个 "Custom..." 兜底走 vim.ui.input。neotest 的 run.run 接受
-- extra_args 直接透传给底层 framework。
local presets_by_ft = {
	python = {
		{ label = "Verbose (-v)", args = { "-v" } },
		{ label = "Fail-fast (-x)", args = { "-x" } },
		{ label = "Last failed (--lf)", args = { "--lf" } },
	},
	go = {
		{ label = "Verbose (-v)", args = { "-v" } },
		{ label = "Fail-fast (-failfast)", args = { "-failfast" } },
		{ label = "No cache (-count=1)", args = { "-count=1" } },
	},
	rust = {
		{ label = "Verbose (--verbose)", args = { "--verbose" } },
		{ label = "Fail-fast (--fail-fast)", args = { "--fail-fast" } },
		{ label = "No fail-fast (--no-fail-fast)", args = { "--no-fail-fast" } },
	},
	javascript = {
		{ label = "Verbose", args = { "--verbose" } },
		{ label = "Bail (--bail)", args = { "--bail" } },
		{ label = "Only failures", args = { "--onlyFailures" } },
	},
}
presets_by_ft.typescript = presets_by_ft.javascript
presets_by_ft.javascriptreact = presets_by_ft.javascript
presets_by_ft.typescriptreact = presets_by_ft.javascript

local function run_with_args_picker()
	local ft = vim.bo.filetype
	local presets = presets_by_ft[ft] or {}
	local choices = {}
	for _, p in ipairs(presets) do
		table.insert(choices, p.label)
	end
	table.insert(choices, "Custom...")

	vim.ui.select(choices, { prompt = "Run nearest with:" }, function(choice)
		if not choice then
			return
		end
		if choice == "Custom..." then
			vim.ui.input({ prompt = "Extra args: " }, function(args)
				if not args or args == "" then
					return
				end
				require("neotest").run.run({
					extra_args = vim.split(args, "%s+", { trimempty = true }),
				})
			end)
			return
		end
		for _, p in ipairs(presets) do
			if p.label == choice then
				require("neotest").run.run({ extra_args = p.args })
				return
			end
		end
	end)
end

-- ============================================================================
-- "Drop stuck" —— 强制清掉卡在 running 态的 position。
-- ----------------------------------------------------------------------------
-- 触发场景：cargo 编译失败 / adapter 没解析出 libtest 输出（典型于 Rust
-- 文件里有 panic 之外的 compile error，rustaceanvim 没把 cargo 非零退出
-- 翻译成 result）。表现是 summary 里某个 position 永远转圈。
--
-- neotest 的状态机里 "编译失败" 不是合法的 test status。`run.stop(pos)` 只发
-- SIGINT 给进程；进程已经退出时它是 no-op，**不**清 running 态。也没有公共
-- API 能"设结果"——result 只能由 adapter 上报。
--
-- 解法：合成一个 failed result，用 `client._state:update_results(adapter_id,
-- results, partial=false)` 喂回去。state.lua 在 partial=false 分支会把
-- `_running[adapter_id][pos_id]` 置 nil 并 emit RESULTS 事件，所有 consumer
-- (status / summary / 我们的 pending) 自动刷新。
--
-- 私有 API 的代价：`client._state` 是 `_` 前缀字段，上游若改名要跟着调。
-- 整个 neotest v5+ 都是这布局，风险可控。换的是"终于能从卡死状态恢复"。
--
-- 为了能拿到 client 引用，注册一个空 consumer (`drop_consumer`)——它的
-- 唯一作用是在 setup 时把 client 对象捕获到 file-local 变量里，然后
-- `drop_stuck()` 能从 keymap 调到。consumer 被 setup 调用 = 必经路径。
-- ============================================================================
local captured_client

local function drop_consumer(client)
	captured_client = client
end

local function drop_stuck()
	if not captured_client then
		vim.notify("neotest: client not captured yet (run setup / a test first)", vim.log.levels.WARN)
		return
	end

	local nt = require("neotest")
	local total = 0
	local labels = {}

	for _, adapter_id in ipairs(nt.state.adapter_ids()) do
		local tree = nt.state.positions(adapter_id)
		if tree then
			local synth = {}
			for _, node in tree:iter_nodes() do
				local pos = node:data()
				-- 三种 position 都可能卡：
				--   * test       —— 单测被 update_running 后没回 result
				--   * namespace  —— mod / describe / suite 级聚合卡
				--   * file       —— `<leader>tT` 整文件跑常被锁在这一层
				--                   (rustaceanvim 发 update_running 给 file id，
				--                   cargo 编译失败时 result 永远不回)
				-- 排除 dir：dir 是合成节点，自己没 running 状态。
				if pos.type ~= "dir" and captured_client:is_running(pos.id, { adapter = adapter_id }) then
					total = total + 1
					table.insert(labels, ("  • [%s] %s"):format(pos.type, pos.name or pos.id))
					synth[pos.id] = {
						status = "failed",
						short = "neotest: dropped (stuck without result — likely compile error or no libtest output)",
						errors = {},
					}
					-- 顺手对真在跑的进程发一下 stop——已退出就 no-op
					pcall(function()
						nt.run.stop(pos.id)
					end)
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

return {
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-neotest/nvim-nio",
			-- 语言 adapter（Go / Python / TS-Jest / Rust）
			-- Go 用 fredrikaverpil/neotest-golang 而非 nvim-neotest/neotest-go：
			-- 后者 2024-05 起停滞，table tests / nearest / dap-go 集成都有
			-- 已知 bug；neotest-golang 是 2025 活跃维护版（LazyVim 也已切换）。
			"fredrikaverpil/neotest-golang",
			"nvim-neotest/neotest-python",
			"nvim-neotest/neotest-jest",
			-- Rust adapter 来自 rustaceanvim（rouge8/neotest-rust 已 archived）。
			-- spec 主体在 plugins/lang/rust.lua（带 init/version/ft）；这里列名
			-- 只是把 rustaceanvim 加成 neotest 的 dep，确保 neotest 加载时
			-- rustaceanvim 已在 rtp 上、`require("rustaceanvim.neotest")` 不会
			-- 因为 lazy 没装载就 fail。lazy.nvim 按 plugin name 合并 spec。
			"mrcjkb/rustaceanvim",
		},
		keys = {
			{
				"<leader>tt",
				function()
					require("neotest").run.run()
				end,
				desc = "Run nearest test",
			},
			{
				"<leader>tT",
				function()
					require("neotest").run.run(vim.fn.expand("%"))
				end,
				desc = "Run tests in file",
			},
			{
				"<leader>tl",
				function()
					require("neotest").run.run_last()
				end,
				desc = "Run last test",
			},
			{
				"<leader>td",
				function()
					require("neotest").run.run({ strategy = "dap" })
				end,
				desc = "Debug nearest test",
			},
			{
				"<leader>tA",
				run_with_args_picker,
				desc = "Run nearest with args (picker)",
			},
			{
				"<leader>ts",
				function()
					require("neotest").summary.toggle()
				end,
				desc = "Toggle test summary",
			},
			{
				"<leader>to",
				function()
					require("neotest").output.open({ enter = true, auto_close = true })
				end,
				desc = "Show test output",
			},
			{
				"<leader>tO",
				function()
					require("neotest").output_panel.toggle()
				end,
				desc = "Toggle output panel",
			},
			{
				"<leader>tS",
				-- 双重含义：
				--   1) 列出当前卡在 running 态的 position（每条名字 + 总数）
				--   2) 对每条发 stop（有进程则 SIGINT；已退出则 no-op）+
				--      合成 failed result 强清 _running 字段
				-- 见文件顶部 drop_stuck 注释块。这条键替代了原版的
				-- `require("neotest").run.stop()`——后者只对光标位置生效，
				-- 解不了"summary 里某 test 跨文件卡死"的实际诉求。
				function()
					drop_stuck()
				end,
				desc = "Stop & drop stuck tests",
			},
			{
				"<leader>tw",
				function()
					require("neotest").watch.toggle(vim.fn.expand("%"))
				end,
				desc = "Toggle watch mode",
			},
			-- 失败导航：和 [d/]d (LSP + lint) 彻底分开的专用流。
			-- 原想用 ]t/[t 走 bracket 惯例，但 todo-comments.nvim 已占。
			{
				"<leader>tn",
				function()
					require("neotest").jump.next({ status = "failed" })
				end,
				desc = "Next failed test",
			},
			{
				"<leader>tp",
				function()
					require("neotest").jump.prev({ status = "failed" })
				end,
				desc = "Prev failed test",
			},
		},
		config = function()
			-- Panel q-to-close：neotest 自己没给 summary / output_panel 绑 close
			-- 键（mappings 字段全是 action-on-position，没有 close action），
			-- 但这两个都是常驻 split 面板，与 Trouble / dap-ui 同质——按 q 一键关
			-- 是社区共识。FileType autocmd 上挂 buffer-local nmap，buftype 已经是
			-- "nofile"（neotest 自己设）所以 :close 安全；不影响测试源文件 buffer。
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("UserNeotestPanelClose", { clear = true }),
				pattern = { "neotest-summary", "neotest-output-panel" },
				callback = function(ev)
					vim.keymap.set("n", "q", "<cmd>close<cr>", {
						buffer = ev.buf,
						silent = true,
						desc = "Close neotest panel",
					})
				end,
			})

			-- Custom consumer：在被发现但还没跑过的 test 行放一个 "pending" 标志。
			--
			-- 官方 status consumer (lua/neotest/consumers/status.lua) 只为
			-- passed/failed/running/skipped 定义 sign —— 既没有 result 也不
			-- 在跑的位置直接 return（line 26），所以"已发现未跑"的测试在 gutter
			-- 上没有任何视觉提示。
			--
			-- 这里复刻官方的事件结构（discover_positions / run / results /
			-- test_file_focused），但只为 "无 result 且 不在跑" 的 test 位置
			-- 放标志。priority = 100 远低于官方的 1000 —— 测试一开始跑，status
			-- consumer 立刻盖上 running/passed/failed sign；同时我们自己的
			-- run/results listener 也会在 render_files 里 unplace 旧的 pending
			-- 再重算，不会双重显示。sign group 与官方完全独立，互不干扰。
			--
			-- 通过 neotest.config.consumers 注册 —— neotest.setup() 内部会拿
			-- vim.tbl_extend("error", builtin, user) 合并，名字别撞内置即可
			-- (run/summary/output/output_panel/status/diagnostic/jump/state/watch)。
			-- 注意：所有 vim.fn / vim.api 调用都走 nio.fn / nio.api 代理。
			-- neotest 的 client.listeners.* 在 nvim-nio 协程里跑（"fast context"），
			-- 直接调 vim.fn.bufnr 之类会触发 E5560；nio.fn / nio.api 内部 yield 到
			-- 主循环再 resume，是 neotest 官方 consumer（status / diagnostic）的标
			-- 准做法。
			local function pending_consumer(client)
				local nio = require("nio")
				local sign_group = "neotest-pending"
				local sign_name = "neotest_pending"
				nio.fn.sign_define(sign_name, {
					text = "◌",
					texthl = "DiagnosticHint",
				})

				local function render_files(adapter_id, files)
					for _, file_path in pairs(files) do
						local bufnr = nio.fn.bufnr(file_path)
						if bufnr > 0 and nio.fn.buflisted(bufnr) ~= 0 and nio.api.nvim_buf_is_valid(bufnr) then
							local results = client:get_results(adapter_id)
							local tree = client:get_position(file_path, { adapter = adapter_id })
							if tree then
								nio.fn.sign_unplace(sign_group, { buffer = bufnr })
								local line_count = nio.api.nvim_buf_line_count(bufnr)
								for _, node in tree:iter_nodes() do
									local pos = node:data()
									if pos.range and pos.type == "test" then
										local has_result = results[pos.id] ~= nil
										local is_running = client:is_running(pos.id, { adapter = adapter_id })
										if not has_result and not is_running then
											local lnum = pos.range[1] + 1
											if lnum <= line_count then
												nio.fn.sign_place(0, sign_group, sign_name, bufnr, {
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

				client.listeners.test_file_focused = function(adapter_id, file_path)
					render_files(adapter_id, { file_path })
				end
			end

			require("neotest").setup({
				adapters = {
					require("neotest-golang")({
						-- table tests 在 neotest-golang 默认就支持，不需要 experimental flag
						go_test_args = { "-count=1", "-race" },
					}),
					require("neotest-python")({
						-- runner 优先级：pytest > unittest；用 .venv 里的解释器
						runner = "pytest",
						python = function()
							local venv = vim.fn.getcwd() .. "/.venv/bin/python"
							if vim.fn.executable(venv) == 1 then
								return venv
							end
							return vim.fn.exepath("python3") or "python3"
						end,
					}),
					require("neotest-jest")({
						jestCommand = "pnpm test --",
						jestConfigFile = function()
							local cwd = vim.fn.getcwd()
							for _, name in ipairs({ "jest.config.ts", "jest.config.js" }) do
								local p = cwd .. "/" .. name
								if vim.fn.filereadable(p) == 1 then
									return p
								end
							end
							return nil
						end,
					}),
					-- Rust：rustaceanvim 内置 adapter，发现走 rust-analyzer
					-- 的 runnables 请求（不是 treesitter query），所以
					-- `#[cfg(test)] mod tests`、`#[tokio::test]`、doc tests 等
					-- 凡是 cargo test 跑得到的都识别。配置在 plugins/lang/rust.lua
					-- 的 vim.g.rustaceanvim.tools.test_executor / .server.* 里。
					-- adapter 本身是个 table（不是工厂函数），直接 require 即可。
					require("rustaceanvim.neotest"),
				},
				summary = {
					open = "botright vsplit | vertical resize 50",
					-- 加 vim-fold 助记键（z*）。neotest 的 expand 是 toggle
					-- （component.lua:32-34），所以 za/zo/zc 都映射到同一个 action 是
					-- 正确的——在 closed 节点按 zo 即"打开"，open 节点按 zc 即"关闭"。
					-- zA 走 expand_all（递归展开 cursor 下的子树）。
					-- 不绑 zR/zM —— vim 那两个是 buffer-wide，neotest 没有"全部折叠"
					-- 公开 API（expanded_positions 是组件内部 state），强造会伸手摸私有。
					mappings = {
						expand = { "<CR>", "<2-LeftMouse>", "za", "zo", "zc" },
						expand_all = { "e", "zA" },
					},
				},
				output = { open_on_run = false },
				quickfix = { open = false },
				-- 关键：不把测试失败推到 vim.diagnostic。
				-- 失败导航用专用的 `]t/[t`（neotest.jump），和 LSP/lint 的 [d/]d 隔离。
				diagnostic = { enabled = false },
				-- signs 默认 = true（不显式写也在），这里写出来让意图可见。
				status = {
					enabled = true,
					signs = true,
					virtual_text = false,
				},
				icons = {
					running_animated = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
					passed = "✓",
					running = "●",
					failed = "✗",
					skipped = "○",
					unknown = "?",
					-- 注：pending（未跑过）的 ◌ 由我们自定义 consumer 直接 sign_define，
					-- 不走 neotest 的 icons 表（官方任何 consumer 都不读 pending key）。
				},
				-- 自定义 consumer：
				--   pending —— 给已发现/未跑过的 test 行放 ◌（见 pending_consumer 注释块）
				--   drop    —— 空 consumer，只为捕获 client 引用，给 <leader>tS 的
				--              drop_stuck() 用（见文件顶部 drop_stuck 注释块）
				-- 名字别撞内置（run/summary/output/output_panel/status/diagnostic/
				-- jump/state/watch）—— neotest.setup 内部用 vim.tbl_extend("error")
				-- 合并，撞了直接 throw。
				consumers = {
					pending = pending_consumer,
					drop = drop_consumer,
				},
			})
		end,
	},
}
