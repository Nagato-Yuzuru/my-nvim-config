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
		{ label = "Verbose (-v)",       args = { "-v" } },
		{ label = "Fail-fast (-x)",     args = { "-x" } },
		{ label = "Last failed (--lf)", args = { "--lf" } },
	},
	go = {
		{ label = "Verbose (-v)",            args = { "-v" } },
		{ label = "Fail-fast (-failfast)",   args = { "-failfast" } },
		{ label = "No cache (-count=1)",     args = { "-count=1" } },
	},
	rust = {
		{ label = "Verbose (--verbose)",             args = { "--verbose" } },
		{ label = "Fail-fast (--fail-fast)",         args = { "--fail-fast" } },
		{ label = "No fail-fast (--no-fail-fast)",   args = { "--no-fail-fast" } },
	},
	javascript = {
		{ label = "Verbose",               args = { "--verbose" } },
		{ label = "Bail (--bail)",         args = { "--bail" } },
		{ label = "Only failures",         args = { "--onlyFailures" } },
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

return {
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-neotest/nvim-nio",
			"antoinemadec/FixCursorHold.nvim",
			-- 语言 adapter（Go / Python / TS-Jest / Rust）
			"nvim-neotest/neotest-go",
			"nvim-neotest/neotest-python",
			"nvim-neotest/neotest-jest",
			"rouge8/neotest-rust",
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
				function() require("neotest").run.stop() end,
				desc = "Stop tests",
			},
			{
				"<leader>tw",
				function() require("neotest").watch.toggle(vim.fn.expand("%")) end,
				desc = "Toggle watch mode",
			},
			-- 失败导航：和 [d/]d (LSP + lint) 彻底分开的专用流。
			-- 原想用 ]t/[t 走 bracket 惯例，但 todo-comments.nvim 已占。
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
			require("neotest").setup({
				adapters = {
					require("neotest-go")({
						experimental = { test_table = true },
						args = { "-count=1", "-race" },
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
					require("neotest-rust")({
						-- 自动检测 cargo-nextest（装了就用，没装回退 cargo test）
						-- nextest 比 cargo test 快得多，强烈建议: cargo install cargo-nextest
						args = { "--no-capture" },
						dap_adapter = "codelldb",
					}),
				},
				summary = {
					open = "botright vsplit | vertical resize 50",
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
				},
			})
		end,
	},
}
