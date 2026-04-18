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
                function()
                    if vim.bo.filetype == "python" then
                        vim.lsp.buf.code_action({
                            context = { only = { "source.fixAll.ruff" }, diagnostics = {} },
                            apply = true,
                        })
                        vim.lsp.buf.code_action({
                            context = { only = { "source.organizeImports.ruff" }, diagnostics = {} },
                            apply = true,
                        })
                    end
                    require("conform").format({ async = true, lsp_fallback = true })
                end,
                desc = "Format file",
            },
        },
        config = function()
            local conform = require("conform")
            local formatters_by_ft = require("tools.mason_ensure").get_formatters_by_ft()

            -- ts/js: Deno 项目用 deno fmt，其余用 prettier
            local function pick_js_formatter(bufnr)
                local deno_root = vim.fs.root(bufnr, { "deno.json", "deno.jsonc", "deno.lock" })
                if deno_root then return { "deno_fmt" } end
                return { "prettier" }
            end
            for _, ft in ipairs({ "typescript", "typescriptreact", "javascript", "javascriptreact" }) do
                formatters_by_ft[ft] = pick_js_formatter
            end

            conform.setup({
                formatters_by_ft = formatters_by_ft,
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
