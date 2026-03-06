---
--- Created by colas.
--- Git 状态可视：gutter 标识 + inline blame + diff 视图
--- 对齐 ideavimrc：<leader>vv = ActivateVersionControlToolWindow
---
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
				map("n", "]c", gs.next_hunk, "Next Hunk")
				map("n", "[c", gs.prev_hunk, "Prev Hunk")
				map("n", "<leader>gp", gs.preview_hunk, "Preview Hunk")
				map("n", "<leader>gb", gs.blame_line, "Blame Line (detail)")
				map("n", "<leader>gs", gs.stage_hunk, "Stage Hunk")
				map("n", "<leader>gu", gs.undo_stage_hunk, "Unstage Hunk")
				map("n", "<leader>vv", function()
					gs.diffthis("HEAD") -- 对齐 ideavimrc <leader>vv
				end, "Diff vs HEAD")
			end,
		},
	},
}
