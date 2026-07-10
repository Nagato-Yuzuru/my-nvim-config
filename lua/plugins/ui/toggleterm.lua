-- plugins/ui/toggleterm.lua
-- 设计：内嵌终端尽可能像裸 shell —— Terminal-mode 下 vim 一个常用键都不抢，
-- 唯一逃生舱是 <C-]>（0x1D 独立字节，zsh emacs-mode / fzf / lazygit 均不用）。
-- 为什么不是 <Esc> 或 <C-[>：<C-[> 在字节层面就是 Esc（0x1B），映射它等于映射
-- Esc 本身，物理 Esc 键会被一并劫持——吃掉 zsh 的 Meta 前缀（Alt-.）、fzf 的
-- 取消、lazygit 的返回；kitty 键盘协议也不消歧这一对（实测 CSI 91;5u 仍触发
-- <C-[> 映射）。normal mode 定位成 tmux copy-mode：只在主动按 <C-]> 翻屏/拷
-- 输出时进入。切窗/点击回来自动回 Terminal-mode 由 toggleterm 自身负责——
-- persist_mode=false + start_in_insert=true 时其 BufEnter 处理器
-- （handle_term_enter → set_mode(INSERT)）每次进入都拉回插入。不要再叠加
-- 自定义 startinsert autocmd：实测同一次进入会排队 3 个 startinsert，且上游
-- set_mode 的 vim.schedule 不做当前 buffer 复查（快速切焦点时 insert 会漏进
-- 普通 buffer——上游缺陷，叠加自定义层只会扩大竞态面，修不掉它）。
-- 窗间导航不需要终端侧 <C-h/j/k/l> tmap：<C-]> 出来后走 ui/tmux.lua 的
-- vim-tmux-navigator 统一导航。嵌套 nvim（git commit / $EDITOR）由
-- ui/flatten.lua 转发到宿主实例。
-- nvim-only：JetBrains 终端不归 IdeaVim 管，见 .ideavimrc 的 Terminal
-- asymmetry 注释块（parity 记录的 SSOT 在那边）。
return {
	{
		"akinsho/toggleterm.nvim",
		version = "*",
		keys = {
			{ "<C-x>`", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
		},
		opts = {
			open_mapping = [[<C-x>`]],
			shade_terminals = true,
			direction = "horizontal",
			size = function(term)
				if term.direction == "horizontal" then
					return math.floor(vim.o.lines * 0.28)
				end
				return 20
			end,
			float_opts = { border = "rounded" },
			start_in_insert = true, -- 打开就进插入模式
			-- 不记忆 normal mode：配合 start_in_insert，toggleterm 的 BufEnter
			-- 处理器在每次进入（toggle 重开/切窗/点击）都拉回 Terminal-mode，
			-- 这是“自动回插入”行为的唯一所有者（见文件头）
			persist_mode = false,
			persist_size = false, -- 不记住手动拖过的大小，每次按 size() 重开
			insert_mappings = true, -- 插入模式下也能用 open_mapping
			close_on_exit = true,
			shell = vim.o.shell, -- 跟随当前 shell
		},
		config = function(_, opts)
			require("toggleterm").setup(opts)
			-- pattern 只匹配 toggleterm 自家 buffer（名字带 #toggleterm#N），
			-- 不波及 snacks lazygit 等其他终端
			vim.api.nvim_create_autocmd("TermOpen", {
				group = vim.api.nvim_create_augroup("user_toggleterm", { clear = true }),
				pattern = "term://*toggleterm#*",
				callback = function()
					vim.keymap.set("t", "<C-]>", [[<C-\><C-n>]], {
						buffer = 0,
						silent = true,
						desc = "Terminal: normal mode",
					})
				end,
			})
		end,
	},
}
