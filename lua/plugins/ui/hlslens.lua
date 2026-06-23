-- nvim-hlslens: 在 n/N/*/# 导航时显示 [3/12] 计数 virt_text。
-- 与 flash.nvim 互不干扰：flash 接管 / ? 输入期间的 label 跳转，
-- hlslens 接管输入完成后 n/N 的"还有几个"反馈。
--
-- IdeaVim 那边由 IDE 内建的 Find Bar 提供等价显示，不需要额外配置 ——
-- 这是 nvim-only 的能力补齐，不破坏 parity。

local function hl_map(lhs, rhs, desc)
	return {
		lhs,
		rhs,
		mode = "n",
		desc = desc,
		silent = true,
	}
end

return {
	{
		"kevinhwang91/nvim-hlslens",
		-- CmdlineEnter 覆盖 / ? 进入；keys 触发 n N * # —— 任一首次使用都触发加载。
		event = "CmdlineEnter",
		keys = {
			hl_map(
				"n",
				[[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]],
				"Repeat search forward"
			),
			hl_map(
				"N",
				[[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]],
				"Repeat search backward"
			),
			hl_map("*", [[*<Cmd>lua require('hlslens').start()<CR>]], "Search word forward"),
			hl_map("#", [[#<Cmd>lua require('hlslens').start()<CR>]], "Search word backward"),
			hl_map("g*", [[g*<Cmd>lua require('hlslens').start()<CR>]], "Search partial word forward"),
			hl_map("g#", [[g#<Cmd>lua require('hlslens').start()<CR>]], "Search partial word backward"),
		},
		opts = {
			-- 光标离开匹配区域 / 缓冲区被改 → 自动清掉 lens 与高亮，避免残留干扰。
			calm_down = true,
			-- 仍然全部显示（不只标最近一个），方便扫视上下文匹配密度。
			nearest_only = false,
			-- 行尾空间不够时才用 floating window 覆盖 statusline 显示 lens。
			nearest_float_when = "auto",
		},
	},
}
