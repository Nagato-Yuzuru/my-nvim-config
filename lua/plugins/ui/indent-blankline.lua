---
--- Created by yuzuru.
--- DateTime: 2025/11/4 00:14
---
return {
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        event = { "BufReadPre", "BufNewFile" },
        opts = function()
            local hooks = require("ibl.hooks")

            local palette = {
                "#E06C75", -- red
                "#E5C07B", -- yellow
                "#61AFEF", -- blue
                "#D19A66", -- orange
                "#98C379", -- green
                "#C678DD", -- violet
                "#56B6C2", -- cyan
            }

            -- 统一用 IblRainbow1..7 命名，便于其它插件 link 复用
            local rainbow_groups = {}
            for i, col in ipairs(palette) do
                local name = ("IblRainbow%d"):format(i)
                table.insert(rainbow_groups, name)
            end

            -- 主题变更时重建高亮，避免换色后失效
            hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
                for i, col in ipairs(palette) do
                    vim.api.nvim_set_hl(0, ("IblRainbow%d"):format(i), { fg = col })
                end
            end)

            return {
                indent = {
                    char = "│",
                    highlight = rainbow_groups, -- 彩虹缩进
                },
                scope = {
                    enabled = true,
                    show_start = false,
                    show_end = false,
                    highlight = rainbow_groups, -- 彩虹作用域
                },
                exclude = {
                    filetypes = { "help", "lazy", "mason", "neo-tree", "Trouble", "alpha", "dashboard" },
                    buftypes  = { "terminal", "nofile", "prompt" },
                },
            }
        end,
    },
}
