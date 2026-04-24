-- neotest — 测试 runner，跨语言统一 UX
--
-- 键位（<leader>t* 命名空间）：
--   <leader>tt   run nearest test
--   <leader>tT   run all tests in file
--   <leader>tl   run last test
--   <leader>td   debug nearest test (走 DAP)
--   <leader>ts   toggle summary panel
--   <leader>to   show output for nearest
--   <leader>tO   toggle output panel
--   <leader>tS   stop running tests
--   <leader>tw   toggle watch mode
--
-- IdeaVim 的 <leader>nt (GotoTest) 在 nvim 端不实现 —— neotest 没有 native 的
-- "跳到测试文件"语义，这是有意保留的不对称（见 CLAUDE.md parity map）。

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
