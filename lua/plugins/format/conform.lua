---
--- Created by colas.
--- DateTime: 2025/11/4 13:14
---
return {
    {
        "stevearc/conform.nvim",
        event = "BufWritePre",
        keys = {
            {
                "<leader>ff",
                function() require("conform").format({ async = true, lsp_fallback = true }) end,
                desc = "Format file",
            },
        },
        config = function()
            local ensure = require("tools.ensure_formatter")
            -- 懒触发安装：VeryLazy 时预检一次（不阻塞 UI）
            vim.api.nvim_create_autocmd("User", {
                pattern = "VeryLazy",
                once = true,
                callback = ensure.ensure_all,
            })

            local conform = require("conform")
            conform.setup({
                formatters_by_ft = ensure.get_formatters_by_ft(),
                format_on_save = function(bufnr)
                    local ft = vim.bo[bufnr].filetype
                    if ft == "zsh" then return { lsp_fallback = false } end
                    return { timeout_ms = 1000, lsp_fallback = true }
                end,
            })
            vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
        end,
    },
}
