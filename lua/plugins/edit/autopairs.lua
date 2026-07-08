return {
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		opts = {
			check_ts = true, -- 结合 Treesitter 做更智能的配对
			disable_filetype = { "TelescopePrompt", "snacks_picker_input" },
		},
		config = function(_, opts)
			local npairs = require("nvim-autopairs")
			npairs.setup(opts)

			-- 常见小优化：只在字符串外自动补引号（not_inside_quote 不含注释判断），
			-- 且单词/闭括号后不补
			local Rule = require("nvim-autopairs.rule")
			local cond = require("nvim-autopairs.conds")
			npairs.add_rules({
				Rule('"', '"'):with_pair(cond.not_inside_quote()):with_pair(cond.not_before_regex("[%w%)%]%}]")),
				Rule("'", "'"):with_pair(cond.not_inside_quote()):with_pair(cond.not_before_regex("[%w%)%]%}]")),
				Rule("`", "`"):with_pair(cond.not_inside_quote()),
			})
		end,
	},
}
