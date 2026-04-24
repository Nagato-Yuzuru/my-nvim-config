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

            -- 常见小优化：只在字符串/注释外自动补引号
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
