---
--- leetcode.nvim — 在 Neovim 中刷 LeetCode
--- Keymaps: <localleader>l (,l) prefix
--- 启动: :Leet 打开面板
---

return {
	{
		"kawre/leetcode.nvim",
		build = ":TSUpdate html",
		lazy = true,
		cmd = "Leet",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"3rd/image.nvim",
		},
		opts = {
			lang = "python3",
			image_support = true,

			hooks = {
				["question_enter"] = {
					function()
						-- 只给题目描述面板（ft == "leetcode.nvim"）开自动换行；
						-- 代码窗口是真实语言 ft，不受影响
						vim.schedule(function()
							for _, win in ipairs(vim.api.nvim_list_wins()) do
								local buf = vim.api.nvim_win_get_buf(win)
								local ft = vim.bo[buf].filetype
								if ft == "leetcode.nvim" then
									vim.wo[win].wrap = true
									vim.wo[win].linebreak = true
								end
							end
						end)
					end,
				},
			},

			injector = {
				["golang"] = {
					before = { "package main" },
				},
			},
		},
		keys = {
			{ "<localleader>ll", "<cmd>Leet<CR>", desc = "LeetCode: Menu" },
			{ "<localleader>ld", "<cmd>Leet desc<CR>", desc = "LeetCode: Description" },
			{ "<localleader>lr", "<cmd>Leet run<CR>", desc = "LeetCode: Run" },
			{ "<localleader>ls", "<cmd>Leet submit<CR>", desc = "LeetCode: Submit" },
			{ "<localleader>lp", "<cmd>Leet list<CR>", desc = "LeetCode: Problem list" },
			{ "<localleader>li", "<cmd>Leet info<CR>", desc = "LeetCode: Info" },
			{ "<localleader>lL", "<cmd>Leet lang<CR>", desc = "LeetCode: Change lang" },
			{ "<localleader>lt", "<cmd>Leet tabs<CR>", desc = "LeetCode: Tabs" },
			{ "<localleader>ly", "<cmd>Leet yank<CR>", desc = "LeetCode: Yank solution" },
			{ "<localleader>lo", "<cmd>Leet open<CR>", desc = "LeetCode: Open in browser" },
			{ "<localleader>lR", "<cmd>Leet reset<CR>", desc = "LeetCode: Reset code" },
			{ "<localleader>lD", "<cmd>Leet daily<CR>", desc = "LeetCode: Daily challenge" },
			{ "<localleader>lc", "<cmd>Leet console<CR>", desc = "LeetCode: Console" },
		},
	},
}
