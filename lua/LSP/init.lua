-- ./init.lua 或 Lazynvim 主配置文件
-- ~/.config/nvim/lua/LSP/init.lua
local lspconfig = require("lspconfig")
local cmp_nvim_lsp = require("cmp_nvim_lsp")
local capabilities = cmp_nvim_lsp.default_capabilities(vim.lsp.protocol.make_client_capabilities())

-- 通用 on_attach 函数，包含常用快捷键和诊断配置
local on_attach = function(client, bufnr)
	-- 诊断符号
	-- 新的、推荐的方式
    -- vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
    vim.diagnostic.config({
        float = { border = "rounded" },


        -- 使用官方文档推荐的 signs 结构
        signs = {
            -- 定义文本图标，使用 vim.diagnostic.severity 作为键
            text = {
                [vim.diagnostic.severity.ERROR] = '', -- 错误图标 (加空格)
                [vim.diagnostic.severity.WARN]  = '', -- 警告图标 (加空格)
                [vim.diagnostic.severity.INFO]  = '', -- 信息图标 (加空格)
                [vim.diagnostic.severity.HINT]  = '💡', -- 提示图标 (使用简单的灯泡图标，加空格)
            },
            -- 定义数字列 (行号旁) 的高亮组
            numhl = {
                [vim.diagnostic.severity.ERROR] = 'DiagnosticSignError',
                [vim.diagnostic.severity.WARN]  = 'DiagnosticSignWarn',
                [vim.diagnostic.severity.INFO]  = 'DiagnosticSignInfo',
                [vim.diagnostic.severity.HINT]  = 'DiagnosticSignHint',
            },
        },
    })
    -- 快捷键映射
    local bufopts = { noremap = true, silent = true, buffer = bufnr }
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
    vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, bufopts) -- 更改为 Ctrl+k 避免与默认行为冲突
    vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, bufopts)
    vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, bufopts)
    vim.keymap.set("n", "<space>wl", function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, bufopts)
    vim.keymap.set("n", "<space>D", vim.lsp.buf.type_definition, bufopts)
    vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, bufopts)
    vim.keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, bufopts) -- 在 normal 和 visual 模式下
    vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)
    vim.keymap.set("n", "<space>f", function()
        vim.lsp.buf.format({ async = true })
    end, bufopts) -- 格式化

    vim.keymap.set("n", "[d", function()
        vim.diagnostic.jump({ count = -1, float = true })
    end, bufopts)
    vim.keymap.set("n", "]d", function()
        vim.diagnostic.jump({ count = 1, float = true })
    end, bufopts)
    vim.keymap.set("n", "<space>e", vim.diagnostic.open_float, bufopts) -- 显示行诊断信息
    vim.keymap.set("n", "<space>q", vim.diagnostic.setloclist, bufopts) -- 将诊断信息放入 location list

    -- (可选) 根据服务器能力设置保存时自动格式化
    -- if client.supports_method("textDocument/formatting") then
    --   vim.api.nvim_create_autocmd("BufWritePre", {
    --     group = vim.api.nvim_create_augroup("LspFormatOnSave_"..bufnr, { clear = true }),
    --     buffer = bufnr,
    --     callback = function() vim.lsp.buf.format({ bufnr = bufnr, timeout_ms = 500 }) end -- 设置超时避免卡顿
    --   })
    -- end
end

-- 使用 mason-lspconfig 来获取已安装的服务器并自动设置
require("mason-lspconfig").setup_handlers({
    -- 默认处理器，为每个安装的服务器调用 lspconfig.setup
    function(server_name)
        local opts = {
            on_attach = on_attach,
            capabilities = capabilities,
        }

        -- == 特定服务器的配置 ==

        if server_name == "lua_ls" then
            opts.settings = {
                Lua = {
                    runtime = { version = "LuaJIT" },
                    diagnostics = { globals = { "vim" } },
                    workspace = {
                        library = vim.api.nvim_get_runtime_file("", true),
                        checkThirdParty = false, -- 避免检查 ~/.local/share/nvim/lazy/*
                    },
                    telemetry = { enable = false },
                },
            }
        elseif server_name == "pyright" then
            opts.settings = {
                python = {
                    analysis = {
                        autoSearchPaths = true,
                        useLibraryCodeForTypes = true,
                        diagnosticMode = "workspace", -- 分析整个工作区
                        -- typeCheckingMode = "basic" -- 或 "strict"
                    },
                },
            }
        elseif server_name == "gopls" then
            opts.settings = {
                gopls = {
                    analyses = {
                        unusedparams = true,
                    },
                    staticcheck = true,
                    -- usePlaceholders = true, -- 自动填充结构体字段
                    -- completeUnimported = true, -- 补全未导入的包
                },
            }
        elseif server_name == "bashls" then
            -- bashls 通常不需要特殊配置，但 mason-lspconfig 会自动关联
            -- lspconfig 默认会将 bashls 关联到 bash, sh。我们需要确保 zsh 也被包含。
            -- mason-lspconfig 通常会处理好这个，但如果不行，可以在这里强制指定:
            -- opts.filetypes = { "sh", "bash", "zsh" }
            -- 注意：Zsh 支持可能不完美
            -- 检查 shellcheck 是否已安装
            opts.filetypes = { "sh", "bash", "zsh" }
            opts.settings = {
                bashIde = {
                    shellcheckPath = vim.fn.exepath("shellcheck") or "", -- 显式告知 shellcheck 路径
                },
            }
        elseif server_name == "yamlls" then
            opts.settings = {
                yaml = {
                    -- schemas = require('schemastore').yaml.schemas(), -- 如果安装了 schemastore
                    validate = true,
                    format = { enable = false }, -- 让 none-ls (prettier) 处理格式化
                },
            }
        elseif server_name == "jsonls" then
            opts.settings = {
                json = {
                    -- schemas = require('schemastore').json.schemas(), -- 如果安装了 schemastore
                    validate = { enable = true },
                    format = { enable = false }, -- 让 none-ls (prettier) 处理格式化
                },
            }
            -- elseif server_name == "marksman" then -- Markdown LSP 示例
            --   -- marksman 配置
        end

        -- 使用 lspconfig 启动服务器
        lspconfig[server_name].setup(opts)
    end,
})

-- (可选) 添加 schemastore.nvim 插件依赖 (如果使用 JSON/YAML schemas)
-- 在 init.lua 的 lazy.setup 中添加: { "b0o/schemastore.nvim" }

-- 配置诊断信息的显示样式
vim.diagnostic.config({
    virtual_text = true, -- 在行尾显示诊断信息（简洁）
    signs = true,
    underline = true,
    update_in_insert = false, -- 插入模式下不更新诊断，提升性能
    severity_sort = true,
})

-- -- 更改诊断浮动窗口边框
-- local handlers = {
--     ["textDocument/hover"] = vim.lsp.with(vim.lsp.buf.signature_help, { border = "rounded" }),
--     ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.buf.signature_help, { border = "rounded" }),
-- }
-- for name, handler in pairs(handlers) do
--     vim.lsp.handlers[name] = handler
-- end
