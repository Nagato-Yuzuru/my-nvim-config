return {
    {
        "HiPhish/rainbow-delimiters.nvim",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            local rainbow = require("rainbow-delimiters")

            vim.g.rainbow_delimiters = {
                strategy = {
                    [""] = rainbow.strategy["global"],
                    vim  = rainbow.strategy["local"],
                },
                query = {
                    [""] = "rainbow-delimiters",
                    lua  = "rainbow-blocks", -- 对 Lua 用块级配色更舒服
                },
                -- 可选：自定义高亮组，默认已适配大多数主题（tokyonight 也 OK）
                highlight = { "RainbowDelimiterRed", "RainbowDelimiterYellow", "RainbowDelimiterBlue",
                    "RainbowDelimiterOrange", "RainbowDelimiterGreen", "RainbowDelimiterViolet", "RainbowDelimiterCyan" },
            }

        end,
        -- treesitter 由 ts-install + vim.treesitter.start() 提供，无需 nvim-treesitter 依赖
    },
}
