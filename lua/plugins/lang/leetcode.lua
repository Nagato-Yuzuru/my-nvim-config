---
--- leetcode.nvim — 在 Neovim 中刷 LeetCode
--- Keymaps: <localleader>L (,L) prefix，buffer-local，只挂在题目 buffer 上
--- 启动: :Leet 打开面板
---
--- 键位不走 lazy 的 keys 表：那是全局映射，会把 ,L 命名空间漏进所有
--- buffer 的 which-key。改在 question_enter hook 里对题目 buffer 逐个
--- buffer-local 注册。前缀用大写 L 而非 l：解题 buffer 的 ft 是真实语言，
--- 若将来 lang = "racket"，Conjure 会在同一 buffer 挂 buffer-local 的
--- ,e/,l/,c/,g（,l = Log），小写 l 会在 buffer 内部撞车；,L 在 Conjure /
--- paredit(,p) / DAP session 键 / 其他 ft 的大写位（,P ,G ,E ,R）里均无主。

-- 题目 buffer（解题代码 + 描述面板）的 ,L* 映射。幂等，重复调用安全。
local function set_question_keymaps(buf)
	local maps = {
		{ "l", "", "Menu" },
		{ "d", " desc", "Description" },
		{ "r", " run", "Run" },
		{ "s", " submit", "Submit" },
		{ "p", " list", "Problem list" },
		{ "i", " info", "Info" },
		{ "L", " lang", "Change lang" },
		{ "t", " tabs", "Tabs" },
		{ "y", " yank", "Yank solution" },
		{ "o", " open", "Open in browser" },
		{ "R", " reset", "Reset code" },
		{ "D", " daily", "Daily challenge" },
		{ "c", " console", "Console" },
	}
	for _, m in ipairs(maps) do
		vim.keymap.set("n", "<localleader>L" .. m[1], "<cmd>Leet" .. m[2] .. "<CR>", {
			buffer = buf,
			desc = "LeetCode: " .. m[3],
		})
	end
	local ok, wk = pcall(require, "which-key")
	if ok then
		wk.add({ { "<localleader>L", group = "LeetCode", buffer = buf } })
	end
end

return {
	{
		"kawre/leetcode.nvim",
		build = ":TSUpdate html",
		lazy = true,
		cmd = "Leet",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"3rd/image.nvim",
		},
		opts = {
			lang = "python3",
			image_support = true,

			hooks = {
				["question_enter"] = {
					function(q)
						-- q.bufnr 在 hook 触发前已由 create_buffer() 填好（见 handle_mount）
						set_question_keymaps(q.bufnr)
						-- 只给题目描述面板（ft == "leetcode.nvim"）开自动换行；
						-- 代码窗口是真实语言 ft，不受影响。顺带给面板也挂 ,L* ——
						-- 在描述里读完题直接 ,Lr / ,Ls。
						vim.schedule(function()
							for _, win in ipairs(vim.api.nvim_list_wins()) do
								local buf = vim.api.nvim_win_get_buf(win)
								local ft = vim.bo[buf].filetype
								if ft == "leetcode.nvim" then
									vim.wo[win].wrap = true
									vim.wo[win].linebreak = true
									set_question_keymaps(buf)
								end
							end
						end)
					end,
				},
			},

			injector = {
				["golang"] = {
					before = { "package main" },
				},
			},
		},
	},
}
