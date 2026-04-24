-- overseer.nvim — task runner，对应 IdeaVim 的 Run Tool Window
--
-- 键位：
--   <leader>vr   toggle Overseer panel    ← IdeaVim ActivateRunToolWindow parity
--   <leader>or   run task (picker)
--   <leader>oR   rerun last task
--   <leader>oo   task action menu
--   <leader>oc   cancel running task
--
-- Overseer 默认探测 npm/cargo/just/make 等 task，按 buffer root 自动列出。

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
		},
		opts = {
			task_list = {
				direction = "bottom",
				min_height = 12,
				max_height = 20,
				default_detail = 1,
			},
			-- 默认模板：自动发现 npm/cargo/make/just/shell 等
			templates = { "builtin" },
			-- 与 dap 协作：debugger 跑测试时，task 输出不被静音
			component_aliases = {
				default = {
					{ "display_duration", detail_level = 2 },
					"on_output_summarize",
					"on_exit_set_status",
					{ "on_complete_notify", system = "unfocused" },
					"on_complete_dispose",
				},
			},
		},
	},
}
