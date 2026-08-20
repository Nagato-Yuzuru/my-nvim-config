-- neotest — 测试 runner,跨语言统一 UX
--
-- 键位(<leader>t* 命名空间 + `[t`/`]t` 导航):
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
-- 诊断流的刻意隔离:
--   neotest 默认会把失败推到 vim.diagnostic —— 会和 LSP / nvim-lint 的
--   [d/]d 混在一起。这里显式 `diagnostic = { enabled = false }` 关掉。
--   测试失败的导航走 <leader>tn/tp(neotest.jump.next/.prev),和 lint/LSP
--   诊断彻底分开,互不污染。
--
-- 注:原想用 ]t/[t 走 vim "bracket 导航"惯例,但 `todo-comments.nvim` 已经
-- 占了那两个键(业界 TODO 注释跳转约定),避让,落回 <leader>t{n,p}。
--
-- IdeaVim 的 <leader>nt (GotoTest) 在 nvim 端不实现 —— neotest 没有 native 的
-- "跳到测试文件"语义,CLAUDE.md 里的保守判断对 Python/Rust 成立;Go/TS 的
-- convention 虽然清晰,但依赖 LSP + 符号查找已经够用,不额外做 go-to 启发式。
--
-- 自定义 consumer(drop = 强清卡死 running / pending = 未跑标志)的逻辑主体
-- 在 lua/tools/neotest_consumers.lua(tested seam,含私有 API 依赖清单);
-- 本文件只在 consumers 表里接线。

-- <leader>tA: IDE 式 "run with extra args" picker。按 filetype 给最常用的
-- preset,加一个 "Custom..." 兜底走 vim.ui.input。neotest 的 run.run 接受
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
}

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

return {
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-neotest/nvim-nio",
			-- 语言 adapter(Go / Python / Rust / Swift)。JS/TS 刻意不接,
			-- 理由见 CLAUDE.md retired 段。
			-- Go 用 fredrikaverpil/neotest-golang 而非 nvim-neotest/neotest-go:
			-- 后者 2024-05 起停滞,table tests / nearest / dap-go 集成都有
			-- 已知 bug;neotest-golang 是 2025 活跃维护版(LazyVim 也已切换)。
			"fredrikaverpil/neotest-golang",
			"nvim-neotest/neotest-python",
			-- Rust adapter 来自 rustaceanvim(rouge8/neotest-rust 已 archived)。
			-- spec 主体在 plugins/lang/rust.lua(带 init/version/ft);这里列名
			-- 只是把 rustaceanvim 加成 neotest 的 dep,确保 neotest 加载时
			-- rustaceanvim 已在 rtp 上、`require("rustaceanvim.neotest")` 不会
			-- 因为 lazy 没装载就 fail。lazy.nvim 按 plugin name 合并 spec。
			"mrcjkb/rustaceanvim",
			-- Swift Testing adapter(mmllr/neotest-swift-testing):仓库已迁至
			-- Codeberg,GitHub 只剩 moved-notice stub,故用 url= 显式指向 Codeberg
			-- (lazy 从末段派生插件名 neotest-swift-testing,require 名不变)。纯
			-- SwiftPM(root=Package.swift,跑 swift test),CLT 即可、不依赖 xcodebuild;
			-- 位置发现走 treesitter,依赖 treesitter.lua 里已装的 swift parser。
			-- 只认 Swift Testing(import Testing / @Test),legacy XCTest 不支持。
			{ url = "https://codeberg.org/mmllr/neotest-swift-testing" },
		},
		keys = {
			{
				"<leader>tt",
				function() require("neotest").run.run() end,
				desc = "Run nearest test",
			},
			{
				"<leader>tT",
				function() require("neotest").run.run(vim.fn.expand("%")) end,
				desc = "Run tests in file",
			},
			{
				"<leader>tl",
				function() require("neotest").run.run_last() end,
				desc = "Run last test",
			},
			{
				"<leader>td",
				function() require("neotest").run.run({ strategy = "dap" }) end,
				desc = "Debug nearest test",
			},
			{
				"<leader>tA",
				run_with_args_picker,
				desc = "Run nearest with args (picker)",
			},
			{
				"<leader>ts",
				function() require("neotest").summary.toggle() end,
				desc = "Toggle test summary",
			},
			{
				"<leader>to",
				function() require("neotest").output.open({ enter = true, auto_close = true }) end,
				desc = "Show test output",
			},
			{
				"<leader>tO",
				function() require("neotest").output_panel.toggle() end,
				desc = "Toggle output panel",
			},
			{
				"<leader>tS",
				-- 双重含义:
				--   1) 列出当前卡在 running 态的 position(每条名字 + 总数)
				--   2) 对每条发 stop(有进程则 SIGINT;已退出则 no-op)+
				--      合成 failed result 强清 _running 字段
				-- 见 tools/neotest_consumers.lua 的 drop_stuck 注释块。这条键替代
				-- 了原版的 `require("neotest").run.stop()`——后者只对光标位置生
				-- 效,解不了"summary 里某 test 跨文件卡死"的实际诉求。
				function() require("tools.neotest_consumers").drop_stuck() end,
				desc = "Stop & drop stuck tests",
			},
			{
				"<leader>tw",
				function() require("neotest").watch.toggle(vim.fn.expand("%")) end,
				desc = "Toggle watch mode",
			},
			-- 失败导航:和 [d/]d (LSP + lint) 彻底分开的专用流。
			-- 原想用 ]t/[t 走 bracket 惯例,但 todo-comments.nvim 已占。
			{
				"<leader>tn",
				function() require("neotest").jump.next({ status = "failed" }) end,
				desc = "Next failed test",
			},
			{
				"<leader>tp",
				function() require("neotest").jump.prev({ status = "failed" }) end,
				desc = "Prev failed test",
			},
		},
		config = function()
			-- Panel q-to-close:neotest 自己没给 summary / output_panel 绑 close
			-- 键(mappings 字段全是 action-on-position,没有 close action),
			-- 但这两个都是常驻 split 面板,与 Trouble / dap-ui 同质——按 q 一键关
			-- 是社区共识。FileType autocmd 上挂 buffer-local nmap,buftype 已经是
			-- "nofile"(neotest 自己设)所以 :close 安全;不影响测试源文件 buffer。
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

			local consumers = require("tools.neotest_consumers")

			require("neotest").setup({
				adapters = {
					require("neotest-golang")({
						-- table tests 在 neotest-golang 默认就支持,不需要 experimental flag
						go_test_args = { "-count=1", "-race" },
						-- <leader>td 的 DAP 接线。默认的 "dap-go" 模式硬依赖
						-- nvim-dap-go 插件;manual 模式复用 dap/delve.lua 的 adapter。
						dap_mode = "manual",
						-- 函数而非 table:上游 dap_manual.lua 原地 mutate 配置表,
						-- table 形式会跨 run 累积 "-test.run" 参数。cwd 不在这里给,
						-- neotest 的 dap strategy 从 runspec 合并(= 测试所在包目录)。
						dap_manual_config = function()
							return {
								type = "delve", -- dap/delve.lua 的 adapter key(不是 dap-go 的 "go")
								name = "Debug test (neotest)",
								request = "launch",
								mode = "test",
							}
						end,
					}),
					require("neotest-python")({
						-- runner 优先级:pytest > unittest;用 .venv 里的解释器
						runner = "pytest",
						python = function()
							local venv = vim.fn.getcwd() .. "/.venv/bin/python"
							if vim.fn.executable(venv) == 1 then
								return venv
							end
							return vim.fn.exepath("python3") or "python3"
						end,
					}),
					-- Rust:rustaceanvim 内置 adapter,发现走 rust-analyzer
					-- 的 runnables 请求(不是 treesitter query),所以
					-- `#[cfg(test)] mod tests`、`#[tokio::test]`、doc tests 等
					-- 凡是 cargo test 跑得到的都识别。配置在 plugins/lang/rust.lua
					-- 的 vim.g.rustaceanvim.tools.test_executor / .server.* 里。
					-- adapter 本身是个 table(不是工厂函数),直接 require 即可。
					require("rustaceanvim.neotest"),
					-- Swift Testing:位置发现走 swift treesitter query;debug-nearest
					-- (<leader>td)运行时自建 type="lldb" 的 dap 配置,复用 dap/lldb.lua
					-- 注册的 lldb adapter。测试文件按 *Test.swift / *Tests.swift 识别。
					require("neotest-swift-testing"),
				},
				summary = {
					open = "botright vsplit | vertical resize 50",
					-- 加 vim-fold 助记键(z*)。neotest 的 expand 是 toggle
					-- (component.lua:32-34),所以 za/zo/zc 都映射到同一个 action 是
					-- 正确的——在 closed 节点按 zo 即"打开",open 节点按 zc 即"关闭"。
					-- zA 走 expand_all(递归展开 cursor 下的子树)。
					-- 不绑 zR/zM —— vim 那两个是 buffer-wide,neotest 没有"全部折叠"
					-- 公开 API(expanded_positions 是组件内部 state),强造会伸手摸私有。
					mappings = {
						expand = { "<CR>", "<2-LeftMouse>", "za", "zo", "zc" },
						expand_all = { "e", "zA" },
					},
				},
				output = { open_on_run = false },
				quickfix = { open = false },
				-- 关键:不把测试失败推到 vim.diagnostic。
				-- 失败导航用专用的 `]t/[t`(neotest.jump),和 LSP/lint 的 [d/]d 隔离。
				diagnostic = { enabled = false },
				-- signs 默认 = true(不显式写也在),这里写出来让意图可见。
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
					-- 注:pending(未跑过)的 ◌ 由自定义 consumer 直接 sign_define,
					-- 不走 neotest 的 icons 表(官方任何 consumer 都不读 pending key)。
				},
				-- 自定义 consumer(逻辑在 tools/neotest_consumers.lua):
				--   pending —— 给已发现/未跑过的 test 行放 ◌
				--   drop    —— 空 consumer,只为捕获 client 引用,给 <leader>tS 的
				--              drop_stuck() 用
				-- 名字别撞内置(run/summary/output/output_panel/status/diagnostic/
				-- jump/state/watch)—— neotest.setup 内部用 vim.tbl_extend("error")
				-- 合并,撞了直接 throw。
				consumers = {
					pending = consumers.pending,
					drop = consumers.capture,
				},
			})
		end,
	},
}
