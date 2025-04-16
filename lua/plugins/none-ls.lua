-- ~/.config/nvim/lua/plugins/none-ls.lua
return function()
    local null_ls = require("null-ls")
    local builtins = null_ls.builtins

    -- 尝试加载 none-ls-extras，用于对 ruff 的支持
    -- local extras_ok, extras = pcall(require, "none-ls-extras")
    -- if extras_ok then
    --     extras.setup()
    -- else
    --     vim.notify("none-ls-extras 加载失败，请检查安装状态", vim.log.levels.WARN)
    -- end

    -- 定义 sources 列表，注意有可能 extras 的模块加载失败时返回 nil
    local sources = {
        -- Lua 格式化使用 stylua
        builtins.formatting.stylua,

        require("none-ls.diagnostics.cpplint"),
        require("none-ls.formatting.jq"),
        require("none-ls.code_actions.eslint"),
        -- Python
        -- extras_ok and extras.code_actions and extras.code_actions.ruff or nil,
        -- extras_ok and extras.diagnostics and extras.diagnostics.ruff or nil,
        null_ls.builtins.diagnostics.mypy,
        -- Shell 格式化和诊断
        -- null_ls.builtins.formatting.shfmt.with({
        --     -- 如果需要自定义 shfmt 的参数，可添加 extra_args
        --     extra_args = { "--indent=4", "--case-indent" },
        null_ls.builtins.diagnostics.zsh, -- }),
        -- null_ls.builtins.diagnostics.shellcheck.with({
        --     filetypes = {
        --         "sh",
        --         "bash",
        --         "zsh"
        --     },
        --     extra_args = {
        --         "--external-sources"
        --     }
        -- }),

        -- YAML / JSON 格式化使用 prettier
        null_ls.builtins.formatting.prettier,
    }

    -- 过滤掉可能为 nil 的项
    local filtered_sources = {}
    for _, src in ipairs(sources) do
        if src then
            table.insert(filtered_sources, src)
        end
    end

    null_ls.setup({
        debug = true,
        sources = filtered_sources,
    })

    -- 与 Mason 集成，自动安装列出的工具
    require("mason-null-ls").setup({
        ensure_installed = {
            "stylua", -- Lua 格式化工具
            "ruff", -- Python 代码检查（由 none-ls-extras 支持）
            "shfmt", -- Shell 格式化
            -- "shellcheck", -- Shell 诊断
            "prettier", -- YAML/JSON 格式化
        },
        automatic_installation = true,
    })
end
