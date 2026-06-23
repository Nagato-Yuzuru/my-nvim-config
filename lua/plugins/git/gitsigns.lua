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
			signs_staged = { -- staged（已 git add）—— add/change 用双竖线 ║，
				-- 与 unstaged 的细竖线 ▎ 一眼可辨（stage_hunk 是 toggle，需先看清状态）
				add = { text = "║" },
				change = { text = "║" },
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
				local map = function(mode, l, r, desc) vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc }) end
				-- ]c/[c 带 preview：跳到 hunk 即浮现 diff 浮窗（像 JetBrains gutter 工具条），
				-- 光标离开 hunk 时浮窗自动关；连按则跟着跳到下一个 hunk 重新浮现。
				-- 光标留在正文，故下面 <localleader>g* 动作直接对光标所在 hunk 生效。
				map("n", "]c", function() gs.nav_hunk("next", { preview = true }) end, "Git: Next Hunk (preview)")
				map("n", "[c", function() gs.nav_hunk("prev", { preview = true }) end, "Git: Prev Hunk (preview)")
				map("n", "<localleader>gp", gs.preview_hunk, "Git: Preview Hunk")
				map("n", "<localleader>gb", gs.blame_line, "Git: Blame Line (detail)")
				-- restore：丢弃光标所在 hunk 的工作区改动，恢复到 git base。整 buffer 恢复走命令行
				-- `git checkout -- <file>`，不占键位。
				map("n", "<localleader>gr", gs.reset_hunk, "Git: Restore Hunk (discard)")
				-- stage_hunk 是 toggle：unstaged hunk(▎)上按→暂存；staged hunk(║)上按→取消暂存。
				-- 旧的 undo_stage_hunk(<localleader>gu) 已删除——它是 deprecated 的会话级 LIFO 撤销，
				-- 不作用于光标所在 hunk（终端 git add 的 / 重开 nvim 后一律 No hunks to undo）。
				map("n", "<localleader>gs", gs.stage_hunk, "Git: Stage/Unstage Hunk (toggle)")
				map("n", "<localleader>gd", function() gs.diffthis("HEAD") end, "Git: Diff vs HEAD")
				-- 切换 hunk 计算的 base revision：默认是 index（未提交对比），
				-- 切到 main/origin/main 后 signs、]c/[c、preview/stage_hunk 全部按 vs <base> 工作。
				-- 仅影响 gitsigns；snacks.explorer 的 git 状态来自 `git status`，不受影响。
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
