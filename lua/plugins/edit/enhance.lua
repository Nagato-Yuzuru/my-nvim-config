return {
	{ "michaeljsmith/vim-indent-object" },

	-- matchup.vim (增强 % 匹配)
	{
		"andymass/vim-matchup",
		event = "BufRead",
		init = function()
			vim.g.matchup_matchparen_deferred = 1       -- 延迟高亮，避免每次按键阻塞
			vim.g.matchup_matchparen_deferred_show_delay = 50
			vim.g.matchup_matchparen_deferred_hide_delay = 700
			vim.g.matchup_matchparen_hi_surround_always = 0 -- 只高亮直接匹配对
			vim.g.matchup_treesitter_enabled = 1 -- 已移除 nvim-treesitter 依赖，0.12 兼容
		end,
	},

	-- vim-cool (关闭高亮后增强搜索体验)
	{ "romainl/vim-cool", event = "VeryLazy" },

	-- vim-highlightedyank 已移除（Neovim 0.11+ 内置 vim.hl.on_yank 默认启用）
	{
		"keaising/im-select.nvim",
		event = "VeryLazy",
		cond = function()
			local function binary_exists(name)
				return vim.fn.executable(name) == 1
			end

			return binary_exists("im-select")
				or binary_exists("macism")
				or binary_exists("fcitx5-remote")
				or binary_exists("fcitx-remote")
		end,
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
	-- vim-textobj-parameter / vim-textobj-user 已移除
	-- 参数 text object 统一使用 treesitter textobjects: ia / aa (@parameter)
}
