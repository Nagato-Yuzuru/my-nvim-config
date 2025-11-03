---
--- Created by colas.
--- DateTime: 2025/11/3 19:58
---
return {
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            plugins = { spelling = true },
            win = {
                border = "rounded",
                padding = { 1, 2 },
                -- 如果你想要透明度，which-key v3 把窗口局部选项放到 wo 里：
                -- wo = { winblend = 10 },
            },
            filter = function(mapping)
                return mapping.desc ~= nil
            end,
        },
        config = function(_, opts)
            local wk = require("which-key")
            wk.setup(opts)
            --wk.add({
            --    ["<C-x>"] = { name = "Windows / Tabs" },
            --    ["<leader>f"] = { name = "File / Format" },
            --    ["<leader>g"] = { name = "Generate" },
            --    ["<leader>s"] = { name = "Search" },
            --    ["<leader>t"] = { name = "Terminal / Test" },
            --})
        end,
    },
}
