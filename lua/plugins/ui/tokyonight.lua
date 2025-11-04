---
--- Created by colas.
--- DateTime: 2025/11/3 19:26
---
return {
    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000, -- 先于其他 UI 加载
        opts = {
            style = "moon",
            transparent = false,
            styles = {
                sidebars = "normal",
                floats = "normal",
            },
            on_highlights = function(hl, c)
                -- 覆盖行号
                hl.LineNr = { fg = "#dddddd" }
                hl.CursorLineNr = { fg = "#ff996c" }
            end,
        },
        config = function(_, opts)
            require("tokyonight").setup(opts)
            vim.cmd.colorscheme("tokyonight")
        end,
    },
}
