---
--- Created by yuzuru.
--- DateTime: 2025/11/4 01:30
---
return {
    {
        "saghen/blink.cmp",
        event = "InsertEnter",
        dependencies = {
            "L3MON4D3/LuaSnip",
            "rafamadriz/friendly-snippets", -- 常用片段库
            "onsails/lspkind.nvim",         -- 图标 & item kind
            "xzbdmw/colorful-menu.nvim",    -- 你列表里已有，可选
        },
        opts = {
            keymap = { -- 常用键位
                preset      = "none",
                ["<CR>"]    = { "accept", "fallback" },
                ["<Tab>"]   = { "accept", "fallback" },         -- 等价: select=true 再确认
                ["<A-/>"]   = { "show", "show_documentation" }, -- 触发补全/文档
                --["<C-Esc>"] = { "hide" },                       -- 取消
                ["<C-p>"]   = { "select_prev", "fallback" },    -- 上一个
                ["<C-n>"]   = { "select_next", "fallback" },    -- 下一个
                ["<C-b>"]   = { "scroll_documentation_up", "fallback" },
                ["<C-f>"]   = { "scroll_documentation_down", "fallback" },
                ["<S-Tab>"] = { "select_prev", "fallback" },
            },
            appearance = { use_nvim_cmp_as_default = true },
            sources = {
                default = { "lsp", "path", "buffer", "snippets" },
            },
            completion = {
                menu = {
                    border = "rounded",
                    winblend = 0,
                },
                documentation = {
                    auto_show = true,
                    window = { border = "rounded", winblend = 0 },
                },
            },
            signature = { -- 插入时签名提示（与 <A-P> 互补）
                enabled = true,
                window = { border = "rounded", winblend = 0 },
            },
            snippets = { preset = "luasnip" },
        },
        config = function(_, opts)
            -- 载入片段
            require("luasnip.loaders.from_vscode").lazy_load()

            -- ⚠️ 不要再给 opts 注入 `formatting`（blink 不支持）
            -- if pcall(require, "lspkind") then
            --   ...（省略：blink 目前没有 formatting 钩子）
            -- end

            -- 只保留一次 setup
            require("blink.cmp").setup(opts)

            -- 手动控制补全的键位（blink 的 keymap 里没有 toggle，这里给一个“显式呼出”）
            -- 说明：插入模式，用 Alt-/ 打开补全；关闭用你已经配置的 <C-e>（hide）
        end
    },
}
