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

            -- markdown: 项目显式声明 .mdformat.toml 时走 mdformat（opt-in，由项目自行决定
            -- 是否需要 pymdown / MDX / admonition 等扩展的安全格式化），否则默认 prettier。
            -- 作用域随 .mdformat.toml 位置下沉：放 docs/ 下只影响 docs/；放项目根则全仓库。
            -- 安装：uv tool install mdformat --with mdformat-mkdocs --with mdformat-gfm --with mdformat-frontmatter
            -- mdformat 缺失时跳过 fmt（不降级到 prettier），以免破坏项目已声明要保留的语法。
            local function pick_md_formatter(bufnr)
                if vim.fs.root(bufnr, { ".mdformat.toml" }) then
                    if vim.fn.executable("mdformat") == 1 then return { "mdformat" } end
                    return {}
                end
                return { "prettier" }
            end
            formatters_by_ft.markdown = pick_md_formatter

            conform.setup({
                formatters_by_ft = formatters_by_ft,
                formatters = {
                    -- mdformat 默认校验 "格式化前后 HTML 渲染一致"，但歧义字符（列表中的裸 `*` 等）
                    -- 会被合法地转义触发误报。--no-validate 跳过该检查；MkDocs / MDX 扩展语法
                    -- 仍由对应插件正确保留。
                    mdformat = { prepend_args = { "--no-validate" } },
                },
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
