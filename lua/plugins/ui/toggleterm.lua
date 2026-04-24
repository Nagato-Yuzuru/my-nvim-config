return {
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        keys = {
            { "<C-x>`", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
        },
        opts = {
            open_mapping = [[<C-x>`]],
            shade_terminals = true,
            direction = "horizontal",
            size = function(term)
                if term.direction == "horizontal" then
                    return math.floor(vim.o.lines * 0.28)
                end
                return 20
            end,
            float_opts = { border = "rounded" },
            start_in_insert = true, -- 打开就进插入模式
            persist_size = false,   -- 记住大小
            insert_mappings = true, -- 插入模式下也能用 open_mapping
            close_on_exit = true,
            shell = vim.o.shell,    -- 跟随当前 shell
        },
        config = function(_, opts)
            require("toggleterm").setup(opts)
            -- 终端内常用按键：退出/切窗（像 IDE 一样顺手）
            vim.api.nvim_create_autocmd("TermOpen", {
                pattern = "term://*",
                callback = function()
                    local o = { buffer = 0, noremap = true, silent = true }
                    vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], o) -- 终端 → 普通模式
                    vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], o)
                    vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], o)
                    vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], o)
                    vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], o)
                end,
            })
        end,
    },
}
