-- Diffview：分支级文件树 diff，与 gitsigns（hunk 级）互补。
-- neo-tree 的 git 状态来自 `git status`（vs index/HEAD），无法显示"vs main"的文件列表，
-- 所以分支审视场景走 diffview。
--
-- <leader>vD  指定 base，打开 <base>...HEAD 的文件树 diff
-- <leader>vH  当前分支历史（DiffviewFileHistory）
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
		opts = {
			enhanced_diff_hl = true,
			view = {
				merge_tool = { layout = "diff3_mixed" },
			},
		},
	},
}
