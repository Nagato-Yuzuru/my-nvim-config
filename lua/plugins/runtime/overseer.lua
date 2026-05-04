-- overseer.nvim — task runner，对应 IdeaVim 的 Run Tool Window
--
-- 键位：
--   <leader>vr   toggle Overseer panel    ← IdeaVim ActivateRunToolWindow parity
--   <leader>or   run task (picker)
--   <leader>oR   rerun last task
--   <leader>oo   task action menu
--   <leader>oc   cancel running task
--   <leader>os   ad-hoc shell command (tracked)   ← nvim-only, IDE side uses Run Anything
--
-- Overseer 默认探测 npm/cargo/just/make 等 task，按 buffer root 自动列出。
-- <leader>os 用 expandcmd() 解析 % / <cfile> / ~ 等占位符（和 :! 一致），
-- 任务进 panel 后享受 default component alias（duration / notify / dispose）。

return {
	{
		"stevearc/overseer.nvim",
		cmd = {
			"OverseerRun",
			"OverseerToggle",
			"OverseerOpen",
			"OverseerClose",
			"OverseerInfo",
			"OverseerBuild",
			"OverseerQuickAction",
			"OverseerTaskAction",
			"OverseerClearCache",
		},
		keys = {
			{ "<leader>vr", "<cmd>OverseerToggle<cr>", desc = "Toggle Overseer panel" },
			{ "<leader>or", "<cmd>OverseerRun<cr>", desc = "Run task" },
			{
				"<leader>oR",
				function()
					local overseer = require("overseer")
					local tasks = overseer.list_tasks({ recent_first = true })
					if vim.tbl_isempty(tasks) then
						vim.notify("No tasks to rerun", vim.log.levels.WARN)
						return
					end
					overseer.run_action(tasks[1], "restart")
				end,
				desc = "Rerun last task",
			},
			{ "<leader>oo", "<cmd>OverseerQuickAction<cr>", desc = "Task action menu" },
			{
				"<leader>oc",
				function()
					local tasks = require("overseer").list_tasks({ status = "RUNNING" })
					if vim.tbl_isempty(tasks) then
						vim.notify("No running tasks", vim.log.levels.INFO)
						return
					end
					for _, task in ipairs(tasks) do
						task:stop()
					end
					vim.notify(("Cancelled %d task(s)"):format(#tasks), vim.log.levels.INFO)
				end,
				desc = "Cancel running tasks",
			},
			{
				"<leader>os",
				function()
					local raw = vim.fn.input({ prompt = "Shell $ ", completion = "shellcmd" })
					if not raw or raw == "" then
						return
					end
					local ok, cmd = pcall(vim.fn.expandcmd, raw)
					if not ok then
						vim.notify(cmd, vim.log.levels.ERROR)
						return
					end
					local overseer = require("overseer")
					local task = overseer.new_task({
						name = cmd,
						cmd = cmd,
						components = { "default" },
					})
					task:start()
					overseer.open()
				end,
				desc = "Run shell command (tracked)",
			},
		},
		opts = {
			task_list = {
				direction = "bottom",
				min_height = 12,
				max_height = 20,
				-- 渲染走 task_list.render 函数（默认 format_standard 已含 duration / output summary）
				-- 旧的 display_duration / on_output_summarize component 已废弃，不再用 component 定渲染
			},
			-- 默认模板：自动发现 npm/cargo/make/just 等（无 generic shell 模板，ad-hoc 走 <leader>os）
			templates = { "builtin" },
			-- default component alias —— 仅保留行为类组件，渲染由 task_list.render 接管
			component_aliases = {
				default = {
					"on_exit_set_status",
					{ "on_complete_notify", system = "unfocused" },
					"on_complete_dispose",
				},
			},
		},
	},
}
