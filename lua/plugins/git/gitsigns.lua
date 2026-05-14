-- Git 状态可视：gutter 标识 + inline blame + diff 视图
-- 对齐 ideavimrc：<localleader>G = Vcs.QuickListPopupAction
return {
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		opts = {
			signs = { -- unstaged（工作区改动）
				add = { text = "▎" },
				change = { text = "▎" },
				delete = { text = "" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
			},
			signs_staged = { -- staged（已 git add）
				add = { text = "┃" },
				change = { text = "┃" },
				delete = { text = "" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
			},
			signs_staged_enable = true,
			current_line_blame = true, -- 当前行尾显示 blame ghost text
			current_line_blame_opts = {
				virt_text = true,
				virt_text_pos = "eol",
				delay = 500,
			},
			on_attach = function(bufnr)
				local gs = require("gitsigns")
				local map = function(mode, l, r, desc)
					vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
				end
				map("n", "]c", gs.next_hunk, "Git: Next Hunk")
				map("n", "[c", gs.prev_hunk, "Git: Prev Hunk")
				map("n", "<localleader>gp", gs.preview_hunk, "Git: Preview Hunk")
				map("n", "<localleader>gb", gs.blame_line, "Git: Blame Line (detail)")
				map("n", "<localleader>gs", gs.stage_hunk, "Git: Stage Hunk")
				map("n", "<localleader>gu", gs.undo_stage_hunk, "Git: Unstage Hunk")
				map("n", "<localleader>gd", function()
					gs.diffthis("HEAD")
				end, "Git: Diff vs HEAD")
				-- 切换 hunk 计算的 base revision：默认是 index（未提交对比），
				-- 切到 main/origin/main 后 signs、]c/[c、preview/stage_hunk 全部按 vs <base> 工作。
				-- 仅影响 gitsigns；neo-tree 的 git 状态来自 `git status`，不受影响。
				map("n", "<localleader>gB", function()
					vim.ui.input({ prompt = "Diff base (空=恢复默认): ", default = "main" }, function(rev)
						if rev == nil then
							return
						end
						if rev == "" then
							gs.reset_base(true)
						else
							gs.change_base(rev, true)
						end
					end)
				end, "Git: Change diff base")
			end,
		},
	},
}
