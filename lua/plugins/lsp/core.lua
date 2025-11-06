---
--- Created by yuzuru.
--- DateTime: 2025/11/4 00:46
---
-- lua/plugins/lsp/core.lua
return {
    -- 安装器（装 LSP/DAP/CLI 工具）
    { "williamboman/mason.nvim", build = ":MasonUpdate", config = true },

    -- mason ↔ lspconfig 桥接
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = { "williamboman/mason.nvim" },
        config = function()
            require("mason").setup()
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "lua_ls", "pyright", "gopls", "jsonls", "yamlls",
                    "bashls", "taplo", "marksman", "clangd"
                },
                automatic_installation = true,
            })
        end,
    },
    -- ★ 新 API 版 LSP 启动器
    {
        "neovim/nvim-lspconfig", -- 仅为了 util/根目录工具；不再调用 .setup()
        event = { "BufReadPre", "BufNewFile" },
        cmd = { "LspInfo", "LspLog" },
        dependencies = { "b0o/SchemaStore.nvim" },
        config = function()
            -- 绑定补全能力（blink.cmp 可选）
            local caps = vim.lsp.protocol.make_client_capabilities()
            pcall(function()
                caps = vim.tbl_deep_extend("force", caps, require("blink.cmp").get_lsp_capabilities() or {})
            end)
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("UserLspKeymaps", { clear = true }),
                callback = function(args)
                    local bufnr = args.buf
                    local map = function(mode, lhs, rhs, desc)
                        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, noremap = true, silent = true, desc = desc })
                    end

                    map("n", "<C-q>", vim.lsp.buf.hover, "LSP: Hover") -- 你的习惯
                    map({ "n", "i", "s" }, "<A-P>", vim.lsp.buf.signature_help, "LSP: Signature Help")
                    map("n", "gd", vim.lsp.buf.definition, "Goto Definition")
                    map("n", "gD", vim.lsp.buf.declaration, "Goto Declaration")
                    map("n", "gi", vim.lsp.buf.implementation, "Goto Implementation")
                    map("n", "gr", vim.lsp.buf.references, "References")
                    map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
                    map("n", "<leader>ca", vim.lsp.buf.code_action, "Code Action")

                    -- 可选：自动开启 inlay hints
                    if vim.lsp.inlay_hint then pcall(vim.lsp.inlay_hint, bufnr, true) end
                end,
            })

            -- 统一 on_attach（只放键位，不处理格式化；格式化留给 conform.nvim）
            local on_attach = function(_, bufnr)
                local map = function(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
                end
                if vim.lsp.inlay_hint then pcall(vim.lsp.inlay_hint, bufnr, true) end
            end

            -- 小助手：为某/些 filetype 注册启动一个 LSP
            local function start_for_ft(ft, cfg)
                vim.api.nvim_create_autocmd("FileType", {
                    pattern = ft,
                    callback = function(ev)
                        local root = cfg.root_dir
                            or vim.fs.root(ev.buf, cfg.root_patterns or { ".git" })
                            or vim.fn.getcwd()
                        local final = vim.tbl_deep_extend("force", {
                            name = cfg.name,
                            cmd = cfg.cmd, -- 依赖 mason，将二进制放进 PATH
                            root_dir = root,
                            capabilities = caps,
                            on_attach = on_attach,
                            settings = cfg.settings,
                            single_file_support = (cfg.single_file_support ~= false),
                        }, cfg.extra or {})
                        vim.lsp.start(final)
                    end,
                })
            end

            -- Lua (lua_ls)
            start_for_ft({ "lua" }, {
                name = "lua_ls",
                cmd = { "lua-language-server" },
                root_patterns = { ".luarc.json", ".luacheckrc", ".git" },
                settings = {
                    Lua = {
                        diagnostics = { globals = { "vim" } },
                        workspace = { checkThirdParty = false },
                        hint = { enable = true },
                    },
                },
            })

            -- Python (pyright)
            start_for_ft({ "python" }, {
                name = "pyright",
                cmd = { "pyright-langserver", "--stdio" },
                root_patterns = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
            })

            -- Go (gopls)
            start_for_ft({ "go", "gomod", "gowork", "gotmpl" }, {
                name = "gopls",
                cmd = { "gopls" },
                root_patterns = { "go.work", "go.mod", ".git" },
                settings = {
                    gopls = {
                        usePlaceholders = true,
                        analyses = { unusedparams = true, unreachable = true },
                    },
                },
            })

            -- JSON (jsonls) + SchemaStore
            start_for_ft({ "json", "jsonc" }, {
                name = "jsonls",
                cmd = { "vscode-json-language-server", "--stdio" },
                settings = {
                    json = {
                        schemas = require("schemastore").json.schemas(),
                        validate = { enable = true },
                    },
                },
            })

            -- YAML (yamlls) + SchemaStore
            start_for_ft({ "yaml", "yml" }, {
                name = "yamlls",
                cmd = { "yaml-language-server", "--stdio" },
                settings = {
                    yaml = {
                        keyOrdering = false,
                        schemaStore = { enable = false, url = "" },
                        schemas = require("schemastore").yaml.schemas(),
                    },
                },
            })

            -- Bash / Zsh (bashls)
            start_for_ft({ "sh", "bash", "zsh" }, {
                name = "bashls",
                cmd = { "bash-language-server", "start" },
            })

            -- TOML (taplo)
            start_for_ft({ "toml" }, {
                name = "taplo",
                cmd = { "taplo", "lsp", "stdio" },
            })

            -- Markdown (marksman)
            start_for_ft({ "markdown", "markdown.mdx" }, {
                name = "marksman",
                cmd = { "marksman", "server" },
            })

            -- C / C++ (clangd)
            start_for_ft({ "c", "cpp", "objc", "objcpp" }, {
                name = "clangd",
                cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=never", "--offset-encoding=utf-16" },
                root_patterns = { "compile_commands.json", ".git" },
                extra = { init_options = { fallbackFlags = { "-std=c++20" } } },
            })
        end,
    },
}
