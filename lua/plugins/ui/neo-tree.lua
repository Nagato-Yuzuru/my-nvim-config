---
--- Created by colas.
--- DateTime: 2025/11/3 20:02
---
return {
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        cmd = "Neotree",
        keys = {
            { "<leader>vp", "<cmd>Neotree toggle<cr>", desc = "Explorer" },
        },
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            "MunifTanjim/nui.nvim",
        },
        opts = {
            filesystem = {
                follow_current_file = { enabled = true },
                filtered_items = { hide_dotfiles = false, hide_gitignored = true },
            },
            window = { position = "left", width = 34 },
            mappings = {
                -- 让 Ctrl-hjkl 跳到其他窗口（不是在树里移动光标）
                ["<C-h>"] = function() vim.cmd("wincmd h") end,
                ["<C-j>"] = function() vim.cmd("wincmd j") end,
                ["<C-k>"] = function() vim.cmd("wincmd k") end,
                ["<C-l>"] = function() vim.cmd("wincmd l") end,
            },
        },
    },
}
