-- plugins/ui/toggleterm.lua
-- 设计：内嵌终端尽可能像裸 shell —— Terminal-mode 下 vim 一个常用键都不抢，
-- 唯一逃生舱是 <C-]>（0x1D 独立字节，zsh emacs-mode / fzf / lazygit 均不用）。
-- 为什么不是 <Esc> 或 <C-[>：<C-[> 在字节层面就是 Esc（0x1B），映射它等于映射
-- Esc 本身，物理 Esc 键会被一并劫持——吃掉 zsh 的 Meta 前缀（Alt-.）、fzf 的
-- 取消、lazygit 的返回；kitty 键盘协议也不消歧这一对（实测 CSI 91;5u 仍触发
-- <C-[> 映射）。normal mode 定位成 tmux copy-mode：只在主动按 <C-]> 翻屏/拷
-- 输出时进入，切窗回来自动回 Terminal-mode（见下面 WinEnter autocmd）。
-- 窗间导航不再需要终端侧 <C-h/j/k/l> tmap：<C-]> 出来后走 ui/tmux.lua 的
-- vim-tmux-navigator 统一导航。嵌套 nvim（git commit / $EDITOR）由
-- ui/flatten.lua 转发到宿主实例。
-- nvim-only：JetBrains 终端不归 IdeaVim 管，无需镜像 .ideavimrc。
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
			persist_mode = false, -- 不记住上次停在 normal mode，每次 toggle 都落回 Terminal-mode
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
				pattern = "term://*toggleterm#*",
				callback = function()
					vim.keymap.set("t", "<C-]>", [[<C-\><C-n>]], {
						buffer = 0,
						silent = true,
						desc = "Terminal: normal mode",
					})
				end,
			})
			-- 切窗/点击回到终端窗口时自动回 Terminal-mode。
			-- schedule + 复查 filetype：flatten 的 git-commit 阻塞流程里焦点会连续
			-- 跳变（commit buffer 关闭 → 终端 → 代码窗），同步 startinsert 会把
			-- insert 泄漏进随后聚焦的普通 buffer（实测踩过）
			vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
				pattern = "term://*toggleterm#*",
				callback = function()
					vim.schedule(function()
						if vim.bo.filetype == "toggleterm" then
							vim.cmd.startinsert()
						end
					end)
				end,
			})
		end,
	},
}
