-- mini.diff：显示 buffer vs 最近一次保存的 diff，和 gitsigns（vs git base）互补。
-- 视觉上 style='number' 染色行号列，不抢 gitsigns 的 signcolumn；语义上 `]h`/`[h`
-- 守 save-diff，`]c`/`[c` 留给 git，两套 source 一一对应。
--
-- 默认键位（当前都空闲，保留 mini.diff 默认）：
--   ]h / [h      next / prev hunk
--   ]H / [H      last / first hunk
--   gh{motion}   apply：把改动写回 reference —— save() 下 = 重置 save 基线，慎按
--   gH{motion}   reset：撤回到 reference —— save() 下 = 撤回到上次保存
--   gh (o / x)      hunk text object：dgh 删 hunk、ygh 拷 hunk、vgh 选 hunk
--   <localleader>do toggle overlay：virtual text 显示删除行 + 改动行的 word-level diff
return {
	{
		"echasnovski/mini.diff",
		version = false,
		event = { "BufReadPre", "BufNewFile" },
		keys = {
			{
				"<localleader>do",
				function()
					require("mini.diff").toggle_overlay(0)
				end,
				desc = "Diff overlay (vs save)",
			},
		},
		opts = function()
			local diff = require("mini.diff")
			return {
				source = diff.gen_source.save(),
				view = { style = "number" },
			}
		end,
	},
}
