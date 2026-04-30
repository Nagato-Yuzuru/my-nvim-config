-- 键位对齐 .ideavimrc multiple-cursors 配置
-- 使用 multicursor.nvim（纯 Lua，性能优于 vim-visual-multi）
return {
	{
		"jake-stewart/multicursor.nvim",
		branch = "1.0",
		event = "VeryLazy",
		config = function()
			local mc = require("multicursor-nvim")
			mc.setup()
			local set = vim.keymap.set

			-- ── 词匹配模式（对齐 ideavimrc）──────────────────────────
			-- <A-n>   SelectNextOccurrence
			set({ "n", "x" }, "<A-n>", function()
				mc.matchAddCursor(1)
			end, { desc = "MC: Select Next" })
			-- <A-S-n> SelectAllOccurrences
			set({ "n", "x" }, "<A-S-n>", mc.matchAllAddCursors, { desc = "MC: Select All" })
			-- <A-x>   FindNextOccurrence（跳过当前，找下一个）
			set({ "n", "x" }, "<A-x>", function()
				mc.matchSkipCursor(1)
			end, { desc = "MC: Skip & Next" })
			-- <A-p>   UnselectPreviousOccurrence（移除当前光标）
			set({ "n", "x" }, "<A-p>", mc.deleteCursor, { desc = "MC: Remove Cursor" })

			-- ── 行模式：逐行添加光标 ──────────────────────────────────
			set({ "n", "x" }, "<A-j>", function()
				mc.lineAddCursor(1)
			end, { desc = "MC: Add Cursor Down" })
			set({ "n", "x" }, "<A-k>", function()
				mc.lineAddCursor(-1)
			end, { desc = "MC: Add Cursor Up" })

			-- ── 任意位置：键盘自由放置光标 ──────────────────────────
			-- <A-m>  在当前光标位置添加一个新光标（自由选择）
			set({ "n", "x" }, "<A-m>", mc.addCursor, { desc = "MC: Add cursor here" })

			-- ── 任意位置：鼠标 Ctrl+Click ─────────────────────────────
			set("n", "<c-leftmouse>", mc.handleMouse, { desc = "MC: Click add/remove cursor" })
			set("n", "<c-leftdrag>", mc.handleMouseDrag, { desc = "MC: Drag cursors" })
			set("n", "<c-leftrelease>", mc.handleMouseRelease, { desc = "MC: Finish drag" })

			-- ga 留给 mini.align（交互式对齐）
			-- 逐行添加光标用 <A-j>/<A-k>，或 V 选中后 <A-S-n>

			-- ── 光标间导航 ────────────────────────────────────────────
			set({ "n", "x" }, "<A-Left>", mc.prevCursor, { desc = "MC: Prev Cursor" })
			set({ "n", "x" }, "<A-Right>", mc.nextCursor, { desc = "MC: Next Cursor" })

			-- ── 退出 ─────────────────────────────────────────────────
			-- 没光标时不能完全吃掉 <esc>：要把它 feed 出去，让 floating window /
			-- 通知 /  picker 等能正常被 <esc> 关闭。
			local esc = vim.api.nvim_replace_termcodes("<esc>", true, true, true)
			set("n", "<esc>", function()
				if mc.hasCursors() then
					mc.clearCursors()
				else
					vim.cmd("nohlsearch")
					vim.api.nvim_feedkeys(esc, "n", false)
				end
			end, { desc = "MC: clear cursors / nohlsearch" })
		end,
	},
}
