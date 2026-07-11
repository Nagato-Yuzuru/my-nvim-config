-- plugins/ui/flatten.lua
-- 让内嵌终端里的 `nvim file` / `git commit`（$EDITOR）不再套娃：guest 实例
-- 检测到 $NVIM（宿主自动注入终端子进程的 socket）后，把参数转发给宿主打开，
-- 自己立即退出；gitcommit/gitrebase 与 zsh edit-command-line（<C-x><C-e>）
-- 的临时文件阻塞到宿主里对应窗口关闭，语义与真 shell 一致。配合
-- ui/toggleterm.lua 的“裸 shell”设计。
-- 有意不用 upstream README 的两段 toggleterm 配方（都实测踩过坑）：
--   * “阻塞期间收起终端”——commit buffer 成为唯一窗口后，肌肉记忆的 :wq
--     会关掉最后一个窗口 → 整个 nvim 退出；
--   * “BufWritePost 写入即删”——真 git 语义是编辑器退出才算提交完成，
--     写入即删会让中途 :w 存草稿直接提前提交、之后的编辑被静默丢弃。
-- 清理挂在 QuitPre + bufhidden=wipe 上，见 callbacks 内注释。
return {
	{
		"willothy/flatten.nvim",
		-- callbacks 依赖 v0.5.x 的 post_open 签名与 smart_open 行为，
		-- :Lazy update 跳版本后 re-review（同 go-deep.nvim 政策）
		version = "*",
		-- guest 实例必须抢在其它插件加载前拦截并退出，无法 lazy-load（上游要求）
		lazy = false,
		priority = 1001,
		opts = {
			window = {
				-- 默认 "current" 会把文件开进 toggleterm 那个底部小窗；"alternate"
				-- 盲信 winnr("#")，经历过 lazygit 浮窗等切换后会指回终端自己（实测）。
				-- "smart" 过滤掉 terminal/浮窗，只挑普通编辑窗，适配 edgy dock 布局
				open = "smart",
			},
			callbacks = {
				-- zsh edit-command-line 同步等编辑器进程退出后才把文件读回
				-- BUFFER（函数末尾 `"$(<$1)"`）；guest 不阻塞的话 zsh 在用户
				-- 编辑前就读走了原文，之后的 :wq 内容被静默丢弃。临时文件路径
				-- 形如 /tmp/zshXXXXXX.zsh（TMPPREFIX 默认 /tmp/zsh + 随机串 +
				-- 函数内 TMPSUFFIX=.zsh）。只能按 argv 路径拦：ft=zsh 走
				-- block_for 会误伤普通 `nvim foo.zsh`（prompt 卡到关窗才回）。
				should_block = function(argv)
					for _, arg in ipairs(argv) do
						if arg:match("/tmp/zsh%w+%.zsh$") then
							return true
						end
					end
					return false
				end,
				-- 开始菜单（snacks dashboard）独占 main 区时没有 buftype=="" 的
				-- 普通窗，上游 smart_open 找不到合法目标会退化成在当前（终端）窗
				-- 上劈 split。开文件前把 dashboard 窗换成空普通 buffer，smart 就
				-- 会选中它；两个 buffer 都是 bufhidden=wipe，被换走即自回收。
				pre_open = function()
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						local b = vim.api.nvim_win_get_buf(win)
						if vim.api.nvim_win_get_config(win).zindex == nil and vim.bo[b].buftype == "" then
							return -- 已有普通编辑窗，smart_open 自己能找到
						end
					end
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_dashboard" then
							local scratch = vim.api.nvim_create_buf(true, false)
							vim.bo[scratch].bufhidden = "wipe"
							vim.api.nvim_win_set_buf(win, scratch)
							return
						end
					end
				end,
				post_open = function(bufnr, winnr, _ft, is_blocking)
					if not is_blocking then
						vim.api.nvim_set_current_win(winnr)
						return
					end
					-- 以下只管阻塞 buffer（gitcommit/gitrebase/edit-command-line
					-- 临时文件）：guest 等宿主关窗才退出，窗口都是秒开秒关。
					-- 秒开秒关会踩 neominimap 上游竞态（见 neominimap.lua
					-- exclude_filetypes 的 gitcommit 注释）。gitcommit/gitrebase
					-- 在那边按 ft 排除；ecl 临时文件 ft=zsh 不能按 ft 排——会
					-- 波及普通 zsh 文件——改按 buffer 变量禁用。
					vim.b[bufnr].neominimap_enabled = false
					-- 动作在窗口关闭时完成（flatten 监听 QuitPre/BufUnload 解锁
					-- guest；git 才算提交、zsh 才读回命令行），:w 只是存草稿、无
					-- 副作用；wipe 让残留 buffer 随关窗自动回收
					vim.bo[bufnr].bufhidden = "wipe"
					-- :wq 关窗前，若阻塞窗是最后一个普通窗，先补一个窗放回被顶掉
					-- 的原 buffer——否则关窗瞬间 main 区落空，edgy 的 check_main 兜底
					-- 会乱排布局连终端 dock 一起收掉（实测）。回调幂等（补的窗存在时
					-- 直接 return），故不设 once：:q 因未保存失败后重试仍受保护。
					-- :close 不触发 QuitPre，罕见路径，接受 edgy 兜底。
					vim.api.nvim_create_autocmd("QuitPre", {
						buffer = bufnr,
						callback = function()
							for _, win in ipairs(vim.api.nvim_list_wins()) do
								local b = vim.api.nvim_win_get_buf(win)
								if
									b ~= bufnr
									and vim.bo[b].buftype == ""
									and vim.api.nvim_win_get_config(win).relative == ""
								then
									return -- 还有别的普通窗，edgy 兜底不会触发
								end
							end
							-- 被顶掉的原 buffer 优先从本窗 alternate 拿回（nvim_win_set_buf
							-- 会维护窗口局部的 #），兜底任一 listed 普通 buffer / 新空 buffer
							local prev = vim.fn.bufnr("#")
							if
								prev == -1
								or prev == bufnr
								or not vim.bo[prev].buflisted
								or vim.bo[prev].buftype ~= ""
							then
								prev = nil
								for _, b in ipairs(vim.api.nvim_list_bufs()) do
									if b ~= bufnr and vim.bo[b].buflisted and vim.bo[b].buftype == "" then
										prev = b
										break
									end
								end
							end
							vim.cmd("split")
							vim.api.nvim_win_set_buf(0, prev or vim.api.nvim_create_buf(true, false))
							vim.cmd.wincmd("p") -- 焦点还给阻塞窗，:q 关的才是它
						end,
					})
				end,
			},
		},
	},
}
