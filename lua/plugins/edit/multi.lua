---
--- Created by colas.
--- DateTime: 2025/11/4 19:25
---
return {
    {
        "mg979/vim-visual-multi",
        branch = "master",
        keys = { "<C-n>", "<C-Down>", "<C-Up>" },
        init = function()
            -- 贴近 IdeaVim 手感：<C-n> 选中下一个；可视模式继续 <C-n> 扩大
            vim.g.VM_mouse_mappings = 1
            vim.g.VM_default_mappings = 0
            -- 如需更纯净：vim.g.VM_default_mappings = 0 自己在 which-key 里标注
            vim.g.VM_maps = {
                ["Find Under"]         = "<A-j>",       -- 选中下一个匹配
                ["Find Subword Under"] = "<A-j>",       -- 同上，匹配子词
                ["Select Cursor Down"] = "<A-j>",       -- 向下选一个光标
                ["Select Cursor Up"]   = "<A-p>",       -- 向上选一个光标
                ["Skip Region"]        = "<A-x>",       -- 跳过 / 取消当前选中
                ["Remove Region"]      = "<A-x>",       -- 取消当前光标
                ["Add Cursor Down"]    = "<A-j>",
                ["Add Cursor Up"]      = "<A-p>",
            }
        end,
    },
}
