-- grug-far.nvim: 工作区级（多文件）find & replace —— 结果列在可编辑 buffer 里，
-- 增量预览，确认后才写盘。补的是 JetBrains "Replace in Path"（⌘⇧R）的空缺。
--
-- 与 rip-substitute 的分工（两者都在 <leader>s* search/substitute 命名空间）：
--   <leader>sr  → rip-substitute  当前 buffer 的 :s 加强版   ≙ JetBrains Ctrl+R
--   <leader>sR  → grug-far        整个工作区多文件替换        ≙ JetBrains Ctrl+Shift+R
-- 大小写区分 buffer / project，沿用 <leader>sb / <leader>sB（buffer lines /
-- grep buffers）的惯例。语义级标识符 rename 仍走 LSP <leader>rn / grn，不在此列。
--
-- 引擎默认 ripgrep；PCRE2（lookaround / backreference）在 buffer 内的 Flags 行
-- 输入 -P 开启 —— 和 rip-substitute 的 PCRE2 同一套正则心智。
-- 粒度全在 buffer 内的输入行调：Files Filter（glob/类型）、Paths（目录/文件，
-- 支持 ~ / 环境变量 / <buflist> / <qflist>）、Flags（任意 rg flag）。
--
-- 默认不预填 Files Filter —— workspace 替换的本意就是全局，按需自己加 glob，
-- 避免"悄悄只在当前文件类型里替换"这种意外。
--
-- 依赖：ripgrep（系统已装，brew 默认带 pcre2）。

return {
	{
		"MagicDuck/grug-far.nvim",
		cmd = { "GrugFar", "GrugFarWithin" },
		keys = {
			{
				"<leader>sR",
				function()
					require("grug-far").open({
						prefills = { search = vim.fn.expand("<cword>") },
					})
				end,
				mode = "n",
				desc = "Replace in workspace (grug-far)",
			},
			{
				"<leader>sR",
				function()
					-- 把选区作为 search 预填（多行选区也安全 escape）。
					require("grug-far").with_visual_selection()
				end,
				mode = "x",
				desc = "Replace selection in workspace (grug-far)",
			},
		},
		opts = {
			headerMaxWidth = 80,
			keymaps = {
				close = { n = "q" },
			},
		},
	},
}
