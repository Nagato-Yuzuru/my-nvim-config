-- plugins/ui/flatten.lua
-- 让内嵌终端里的 `nvim file` / `git commit`（$EDITOR）不再套娃：guest 实例
-- 检测到 $NVIM（宿主自动注入终端子进程的 socket）后，把参数转发给宿主打开，
-- 自己立即退出；gitcommit/gitrebase 默认阻塞到宿主里对应 buffer 关闭，语义
-- 与真 shell 一致。配合 ui/toggleterm.lua 的“裸 shell”设计。
-- callbacks 基于 upstream README 的 toggleterm 配方，但有意不采用其
-- “阻塞期间收起终端”部分：终端收起后 commit buffer 是唯一窗口，肌肉记忆
-- 的 :wq 会关掉最后一个窗口 → 整个 nvim 退出（实测）。终端保持可见即永远
-- 有第二个窗口，:wq 安全；shell 反正被 git 阻塞，可见无副作用。
return {
	{
		"willothy/flatten.nvim",
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
				post_open = function(bufnr, winnr, ft, is_blocking)
					if not is_blocking then
						vim.api.nvim_set_current_win(winnr)
					end
					-- commit/rebase buffer 写入即删：:w 即完成提交，不留残窗残 buffer。
					-- 删除前先把还显示它的窗口换到别的普通 buffer——直接 bdelete 会
					-- 连窗口一起关，瞬间只剩 edgy dock（toggleterm），触发 edgy 的
					-- 兜底逻辑把终端也收掉（实测）。:wq 的 q 先于本回调关窗，走不到
					-- swap，落点由 edgy 兜底，安全但终端会被收起。
					if ft == "gitcommit" or ft == "gitrebase" then
						vim.api.nvim_create_autocmd("BufWritePost", {
							buffer = bufnr,
							once = true,
							callback = vim.schedule_wrap(function()
								-- :wq 时 buffer 可能已被 q + bufhidden 回收
								if not vim.api.nvim_buf_is_valid(bufnr) then
									return
								end
								local alt
								for _, b in ipairs(vim.api.nvim_list_bufs()) do
									if b ~= bufnr and vim.bo[b].buflisted and vim.bo[b].buftype == "" then
										alt = b
										break
									end
								end
								for _, win in ipairs(vim.api.nvim_list_wins()) do
									if vim.api.nvim_win_get_buf(win) == bufnr then
										vim.api.nvim_win_set_buf(win, alt or vim.api.nvim_create_buf(true, false))
									end
								end
								vim.api.nvim_buf_delete(bufnr, {})
							end),
						})
					end
				end,
			},
		},
	},
}
