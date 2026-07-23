-- plugins/ui/tmux.lua
return {
	{
		"christoomey/vim-tmux-navigator",
		-- 关掉插件自带映射：它在 $TMUX 内会注册 terminal-mode 的 <C-h/j/k/l>
		-- tnoremap，RHS 是 "\<C-w>:\<C-U> Tmux..."——那是 Vim :terminal 的
		-- termwinkey 语法，nvim 没有，整串按键被原样喂给 shell（C-w 删词、
		-- C-u 清行、再打出 "TmuxNavigateLeft" 回车）。也违反 toggleterm.lua
		-- 文件头的裸 shell 设计：Terminal-mode 不设导航 tmap，<C-]> 出来再走
		-- 下面的 normal-mode 映射（由 keys 提供，不依赖插件默认值）。
		init = function() vim.g.tmux_navigator_no_mappings = 1 end,
		cmd = {
			"TmuxNavigateLeft",
			"TmuxNavigateDown",
			"TmuxNavigateUp",
			"TmuxNavigateRight",
			"TmuxNavigatePrevious",
		},
		keys = {
			{ "<c-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Tmux: navigate left" },
			{ "<c-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Tmux: navigate down" },
			{ "<c-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Tmux: navigate up" },
			{ "<c-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Tmux: navigate right" },
			{ "<c-\\>", "<cmd>TmuxNavigatePrevious<cr>", desc = "Tmux: navigate previous" },
		},
	},
}
