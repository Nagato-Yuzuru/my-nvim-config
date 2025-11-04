---
--- Created by colas.
--- DateTime: 2025/11/4 18:44
---
return {
    {
        "HiPhish/rainbow-delimiters.nvim",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            local rainbow = require("rainbow-delimiters")
            local treesitter = require("nvim-treesitter.configs")
            treesitter.setup {
                ensure_installed = { "lua", "python", "go", "json", "yaml", "bash", "markdown", "html", "javascript", "toml" },
                highlight = { enable = true },
            }

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
        dependencies = { "nvim-treesitter/nvim-treesitter" },
    },
}
