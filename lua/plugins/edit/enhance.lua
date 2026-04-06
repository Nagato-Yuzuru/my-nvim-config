---
--- Created by colas.
--- DateTime: 2025/11/4 19:05
---
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
			vim.g.matchup_treesitter_enabled = 0 -- 禁用 treesitter 引擎（与 0.12 不兼容）
		end,
	},

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
	{ "machakann/vim-highlightedyank", event = "VeryLazy" },
	{ "haya14busa/incsearch-fuzzy.vim", event = "CmdlineEnter" }, -- 可选：/ 的模糊
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
	{
		"kana/vim-textobj-user",
		event = "VeryLazy",
	},
	{
		"sgur/vim-textobj-parameter", -- 参数对象：i, / a,   例如 `di,` 删除当前参数
		event = "VeryLazy",
		dependencies = { "kana/vim-textobj-user" },
	},
}
