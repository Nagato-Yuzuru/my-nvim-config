return {
	"smjonas/inc-rename.nvim",
	cmd = "IncRename",
	-- snacks.nvim 已经在装，让 rename 的 input 用 snacks 的 input 框，
	-- 比 vim cmdline 的 inline preview 更醒目（也保留 inc-rename 的实时预览）。
	opts = { input_buffer_type = "snacks" },
	keys = {
		{
			"<leader>rn",
			function() return ":IncRename " .. vim.fn.expand("<cword>") end,
			expr = true,
			desc = "Rename (incremental preview)",
		},
	},
}
