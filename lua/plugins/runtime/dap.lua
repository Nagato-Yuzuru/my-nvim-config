-- nvim-dap suite —— plugin spec、键位、UI/sign。
--
-- ► Per-adapter 配置在顶层 `dap/<adapter>.lua`（镜像 `lsp/<server>.lua`），
--   由 `lua/core/dap.lua` 加载。新增 adapter = 在 `dap/` 下放一个文件，**不要**
--   在这里堆。详见 CLAUDE.md "Runtime suite" 段。
--
-- ► 安装走 mason-registry 直连（core.dap.ensure_mason），不依赖 mason-nvim-dap。
--   理由：mason-nvim-dap 的 setup_handlers 与"per-adapter 自包含"的拆分模型
--   重复且名字空间不一致（adapter-name vs mason-package-name）。
--
-- 键位：见 dap/<adapter>.lua 的 desc + which-key（运行时 `<leader>d` 弹出）。
-- 完整表也在 CLAUDE.md "Runtime suite" 段。

local function inspect_expr()
	require("dapui")["eval"](nil, { enter = true })
end

return {
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"rcarriga/nvim-dap-ui",
			"nvim-neotest/nvim-nio",
			"theHamsta/nvim-dap-virtual-text",
			"williamboman/mason.nvim",
		},
		keys = {
			{ "<leader>D", function() require("dap").continue() end, desc = "Debug: start / continue" },
			{ "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
			{ "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
			{
				"<leader>dB",
				function()
					vim.ui.input({ prompt = "Breakpoint condition: " }, function(cond)
						if cond and cond ~= "" then
							require("dap").set_breakpoint(cond)
						end
					end)
				end,
				desc = "Conditional breakpoint",
			},
			{ "<leader>dn", function() require("dap").step_over() end, desc = "Step over (next)" },
			{ "<leader>ds", function() require("dap").step_into() end, desc = "Step into" },
			{ "<leader>df", function() require("dap").step_out() end, desc = "Step out (finish)" },
			{ "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
			{ "<leader>de", inspect_expr, mode = { "n", "v" }, desc = "Inspect expression" },
			{ "<leader>dh", function() require("dap.ui.widgets").hover() end, desc = "Hover variable" },
			{ "<leader>dl", function() require("dap").run_last() end, desc = "Run last" },
			{ "<leader>dq", function() require("dap").terminate() end, desc = "Terminate session" },
			{ "<leader>dj", function() require("dap").down() end, desc = "Frame down" },
			{ "<leader>dk", function() require("dap").up() end, desc = "Frame up" },
			{ "<leader>vd", function() require("dapui").toggle() end, desc = "Toggle DAP UI" },
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			-- Sign column 标识 ----------------------------------------------------
			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError", linehl = "", numhl = "" })
			vim.fn.sign_define(
				"DapBreakpointCondition",
				{ text = "◆", texthl = "DiagnosticWarn", linehl = "", numhl = "" }
			)
			vim.fn.sign_define(
				"DapBreakpointRejected",
				{ text = "○", texthl = "DiagnosticHint", linehl = "", numhl = "" }
			)
			vim.fn.sign_define("DapLogPoint", { text = "◉", texthl = "DiagnosticInfo", linehl = "", numhl = "" })
			vim.fn.sign_define(
				"DapStopped",
				{ text = "▶", texthl = "DiagnosticOk", linehl = "DapStoppedLine", numhl = "" }
			)

			-- dap-ui 自动开关 -----------------------------------------------------
			dap.listeners.before.attach.dapui_config = function() dapui.open() end
			dap.listeners.before.launch.dapui_config = function() dapui.open() end
			dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
			dap.listeners.before.event_exited.dapui_config = function() dapui.close() end

			-- 加载所有 dap/<adapter>.lua，安装缺失的 mason 包 -------------------
			local core_dap = require("core.dap")
			local mason_pkgs = core_dap.setup()
			core_dap.ensure_mason(mason_pkgs)

			-- dap-virtual-text：行内显示当前 frame 的局部变量值
			require("nvim-dap-virtual-text").setup({
				enabled = true,
				commented = true,
				virt_text_pos = "eol",
			})

			-- dap-ui ----------------------------------------------------------------
			dapui.setup({
				layouts = {
					{
						elements = {
							{ id = "scopes", size = 0.40 },
							{ id = "breakpoints", size = 0.20 },
							{ id = "stacks", size = 0.20 },
							{ id = "watches", size = 0.20 },
						},
						size = 40,
						position = "left",
					},
					{
						elements = {
							{ id = "repl", size = 0.5 },
							{ id = "console", size = 0.5 },
						},
						size = 0.27,
						position = "bottom",
					},
				},
				floating = { border = "rounded" },
			})
		end,
	},
}
