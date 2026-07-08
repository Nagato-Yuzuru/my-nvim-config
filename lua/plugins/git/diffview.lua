-- Diffview：分支级文件树 diff，与 gitsigns（hunk 级）互补。
-- snacks.explorer 的 git 状态来自 `git status`（vs index/HEAD），无法显示"vs main"的文件列表，
-- 所以分支审视场景走 diffview。
--
-- <leader>vD  指定 base，打开 <base>...HEAD 的文件树 diff
-- <leader>vH  当前文件历史（DiffviewFileHistory %）
-- 在 diffview 内：q 关闭、<tab>/<S-tab> 切文件、g? 看帮助
--
-- IdeaVim 对应：Git → Compare with Branch（无现成 action，IDE 走 UI）
return {
	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
		keys = {
			{
				"<leader>vD",
				function()
					vim.ui.input({ prompt = "Diff base (空=main): ", default = "main" }, function(rev)
						if rev == nil then
							return
						end
						if rev == "" then
							rev = "main"
						end
						vim.cmd("DiffviewOpen " .. rev .. "...HEAD")
					end)
				end,
				desc = "Diffview: vs <base>...HEAD",
			},
			{ "<leader>vH", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: file history" },
		},
		opts = function()
			-- `q` 仅在“选择栏”退出 diffview：左侧 file_panel + 底部 file_history_panel。
			-- diff 编辑窗口里 `q` 保持 Vim 默认的宏录制，不覆盖。
			local q_close = { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } }
			return {
				enhanced_diff_hl = true,
				-- diff4_mixed：上排 OURS | BASE | THEIRS，下排 result。选这个而不是
				-- diff3_mixed 正是为了看 BASE——conflict.lua 把"需要看 base 的复杂
				-- 冲突"整体路由到这里。
				view = { merge_tool = { layout = "diff4_mixed" } },
				keymaps = {
					file_panel = { q_close },
					file_history_panel = { q_close },
				},
			}
		end,
	},
}
