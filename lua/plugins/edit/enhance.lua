return {
	{ "michaeljsmith/vim-indent-object", event = "VeryLazy" },

	-- matchup.vim (增强 % 匹配)
	{
		"andymass/vim-matchup",
		event = "BufRead",
		init = function()
			vim.g.matchup_matchparen_deferred = 1 -- 延迟高亮，避免每次按键阻塞
			vim.g.matchup_matchparen_deferred_show_delay = 50
			vim.g.matchup_matchparen_deferred_hide_delay = 700
			vim.g.matchup_matchparen_hi_surround_always = 0 -- 只高亮直接匹配对
			vim.g.matchup_treesitter_enabled = 1 -- treesitter 集成走独立 flag（nvim-treesitter main 分支无 module 机制）
		end,
	},

	-- auto-nohlsearch：lua/core/hlsearch.lua 用 vim.on_key 原生实现（搜索完成后
	-- 停止移动就自动关高亮，再次 n/N/*/# 等又打开）。

	-- Neovim 0.11+ 内置 vim.hl.on_yank 默认启用，无需 vim-highlightedyank。
	{
		"keaising/im-select.nvim",
		event = "VeryLazy",
		cond = function()
			local function binary_exists(name) return vim.fn.executable(name) == 1 end

			return binary_exists("macism")
				or binary_exists("im-select")
				or binary_exists("fcitx5-remote")
				or binary_exists("fcitx-remote")
		end,
		opts = {
			-- macism 才能在新版 macOS 上可靠切换 CJK↔英文；旧的 im-select 二进制会“图标变了但没真正切”。
			default_command = "macism",
			default_im_select = "com.apple.keylayout.ABC",
			-- 其余保持插件默认，即“取决 nvim mode”的正确行为：
			--   set_default_events  = { "InsertLeave", "CmdlineLeave" } → 离开插入模式切到英文(ABC)
			--   set_previous_events = { "InsertEnter" }                → 回到插入模式恢复上次的中文输入法
		},
	},
	{
		"tommcdo/vim-exchange",
		event = "VeryLazy",
		-- 默认映射：cx（操作）, cxx（整行）, X（可视模式）
	},
	-- 参数 text object 统一使用 treesitter textobjects: ia / aa (@parameter)，
	-- 不需要 vim-textobj-parameter / vim-textobj-user。
}
