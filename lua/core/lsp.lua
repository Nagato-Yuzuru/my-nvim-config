-- 全局 LSP 配置：capabilities / enable / LspAttach keymaps
-- 所有 per-server 配置在顶层 lsp/*.lua，由 vim.lsp.enable() 自动加载

-- 全局 capabilities（VeryLazy 后 blink.cmp 已加载）
vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
        local caps = vim.lsp.protocol.make_client_capabilities()
        pcall(function()
            caps = vim.tbl_deep_extend("force", caps, require("blink.cmp").get_lsp_capabilities())
        end)
        vim.lsp.config("*", { capabilities = caps })
    end,
})

-- 启用 LSP servers
vim.lsp.enable({
    "lua_ls", "pyright", "ruff", "ty", "gopls",
    "jsonls", "yamlls", "bashls", "taplo",
    "marksman", "terraformls", "dockerls", "clangd",
    "just_ls",
    "denols", "vtsls", "eslint",
})

-- LspAttach: 快捷键 + inlay hints
vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserLspKeymaps", { clear = true }),
    callback = function(args)
        local bufnr = args.buf
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, noremap = true, silent = true, desc = desc })
        end
        -- Only register a keymap if the attached server supports the method.
        local map_if = function(method, mode, lhs, rhs, desc)
            if client and client:supports_method(method) then
                map(mode, lhs, rhs, desc)
            end
        end

        pcall(function() vim.lsp.inlay_hint.enable(true, { bufnr = bufnr }) end)

        map("n", "<C-q>", vim.lsp.buf.hover, "LSP: Hover")
        map({ "n", "i", "s" }, "<A-P>", vim.lsp.buf.signature_help, "LSP: Signature Help")
        map("n", "gd", vim.lsp.buf.definition, "Goto Definition")
        map_if("textDocument/declaration", "n", "gD", vim.lsp.buf.declaration, "Goto Declaration")
        map("n", "gi", vim.lsp.buf.implementation, "Goto Implementation")
        map("n", "gr", vim.lsp.buf.references, "References")
        -- <leader>rn is handled by inc-rename.nvim (plugins/lsp/inc-rename.lua)
        map("n", "<leader>ca", vim.lsp.buf.code_action, "Code Action")
        map("n", "<leader>nd", vim.lsp.buf.definition, "Goto Definition")
        map("n", "<leader>nD", vim.lsp.buf.type_definition, "Goto Type Definition")
        map("n", "<leader>ni", vim.lsp.buf.implementation, "Goto Implementation")
    end,
})
