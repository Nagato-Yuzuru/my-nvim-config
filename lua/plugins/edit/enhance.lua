---
--- Created by colas.
--- DateTime: 2025/11/4 19:05
---
return {
	{ "michaeljsmith/vim-indent-object" },

	-- matchup.vim (增强 % 匹配)
	{ "andymass/vim-matchup", event = "BufRead" },

	-- vim-cool (关闭高亮后增强搜索体验)
	{ "romainl/vim-cool", event = "VeryLazy" },

	{
		"haya14busa/incsearch.vim",
		event = "CmdlineEnter", -- 进入 / 或 ? 时加载
		config = function()
			-- / 和 ? 默认就是增量; 这里提供几个更顺手的额外映射（可选）
			-- nnoremap /  <Cmd>set hlsearch<CR><Plug>(incsearch-forward)
			-- nnoremap ?  <Cmd>set hlsearch<CR><Plug>(incsearch-backward)
			-- nnoremap g/ <Cmd>set hlsearch<CR><Plug>(incsearch-stay)
		end,
	},
	{ "machakann/vim-highlightedyank" },
	{ "haya14busa/incsearch-fuzzy.vim", event = "CmdlineEnter" }, -- 可选：/ 的模糊
	{
		"keaising/im-select.nvim",
		event = "VeryLazy",
		opts = {
			default_im_select = "com.apple.keylayout.ABC",
			set_previous_events = { "InsertLeave", "CmdlineLeave" },
			default_command = "im-select",
			-- restore_events      = { "InsertEnter", "CmdlineEnter" },
		},
	},
	{
		"tommcdo/vim-exchange",
		event = "VeryLazy",
		-- 默认映射：cx（操作）, cxx（整行）, X（可视模式）
	},
	{
		"kana/vim-textobj-user",
		event = "VeryLazy",
	},
	{
		"sgur/vim-textobj-parameter", -- 参数对象：i, / a,   例如 `di,` 删除当前参数
		event = "VeryLazy",
		dependencies = { "kana/vim-textobj-user" },
	},
	{ "machakann/vim-highlightedyank", event = "VeryLazy" },
	{ "romainl/vim-cool", event = "VeryLazy" },
}
