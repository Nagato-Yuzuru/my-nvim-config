vim.g.mapleader = " "
vim.g.maplocalleader = ","

vim.opt.clipboard = "unnamedplus"


require("core.options")
require("core.keymaps")
-- Lazynvim load
-- require("core.lazy")
-- Neovim configuration
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", lazypath,
    })
end


---------------------------------------------------------------------------
--   Lazy.nvim 插件分层导入结构说明
--
--  本配置采用模块化分层结构，通过 lazy.nvim 的 `spec.import` 字段
--  将插件声明按职责域划分。每个目录下的 Lua 文件需 `return` 插件表。
--
--  ⚙ 顶层结构：
--      lua/
--        core/          -- 非插件配置（纯 Neovim 行为）
--        plugins/       -- 所有插件模块
--          lsp/         -- LSP 生态
--          diagnostics/ -- 非 LSP 格式化/诊断
--          completion/  -- 补全系统（cmp/blink/snippet）
--          dap/         -- 调试器生态
--          search/      -- 文件与代码搜索
--          ui/          -- 外观与交互增强
--          git/         -- Git 生态
--          lang/        -- 语言/文件类型特化
--
--  每层职责与典型内容：
--
--  { import = "plugins" }
--      ▶ 通用插件层
--        - Treesitter 基础解析
--        - Comment.nvim / Surround / Autopairs 等文本行为增强
--        - bufferline / toggleterm / which-key / indent-blankline 等
--        - colorscheme（tokyonight/catppuccin等）
--        - 轻量 UI 与工作流工具
--
--  { import = "plugins.lsp" }
--      ▶ LSP 主干
--        - mason.nvim / mason-lspconfig.nvim / nvim-lspconfig
--        - 各语言服务器 setup（lua_ls, pyright, gopls, jsonls, yamlls...）
--        - SchemaStore（JSON/YAML 自动 schema）
--        - LSP UI 辅助（如 navic, fidget, lsp-status）
--      ✱ 与具体语言无关的 server 初始化统一放此层。
--
--  { import = "plugins.diagnostics" }
--      ▶ 非 LSP 诊断层
--        - none-ls.nvim / mason-null-ls.nvim / none-ls-extras.nvim
--        -  nvim-lint 组合
--        - 代码格式化、静态检查、Linter 桥接
--      ✱ 设计目标：工具层与 LSP 解耦；切换实现不影响上层逻辑。
--  { import = "plugins.format" }
--      ▶ 非 LSP 格式化
--        - 使用conform.nvim 做统一格式化
--      ✱ 设计目标：工具层与 LSP 解耦；切换实现不影响上层逻辑。
--
--  { import = "plugins.completion" }
--      ▶ 自动补全层
--        - nvim-cmp / blink.cmp / LuaSnip / cmp-* 源插件
--        - lspkind.nvim / colorful-menu.nvim / friendly-snippets
--      ✱ 专注“输入体验”，与 LSP 的初始化解耦。
--
--  { import = "plugins.dap" }
--      ▶ 调试层
--        - nvim-dap / mason-nvim-dap.nvim / nvim-dap-ui
--        - nvim-dap-virtual-text / dap-go / dap-python
--      ✱ 独立于 LSP；聚焦调试器适配与 UI 面板。
--
--  { import = "plugins.search" }
--      ▶ 搜索/导航层
--        - telescope.nvim / fzf-lua / project.nvim
--        - treesitter-context / aerial.nvim / trouble.nvim
--        - neo-tree.nvim 或 nvim-tree.lua
--      ✱ 面向“找文件、找符号、找诊断”的全局导航。
--
--  { import = "plugins.ui" }
--      ▶ 界面与交互层
--        - 主题、状态栏、tabline、winbar、美化、通知系统
--        - noice.nvim / lualine.nvim / dressing.nvim / notify.nvim
--      ✱ 任何改善外观或交互体验的插件均可放此。
--
--  { import = "plugins.git" }
--      ▶ Git 集成层
--        - gitsigns.nvim / vim-fugitive / diffview.nvim / neogit
--        - 解决版本控制与代码审阅场景
--      ✱ 独立于 UI 层，方便按需启用或裁剪。
--
--  { import = "plugins.lang" }
--      ▶ 语言/文件类型特化层
--        - markdown 渲染与预览（render-markdown.nvim / peek.nvim）
--        - go.nvim / rust-tools.nvim / typescript.nvim
--        - csvview / sqls / latex / json 工具
--      ✱ 放置与具体文件类型强相关但非 LSP 初始化的插件。
--
--   设计原则：
--      • 所有文件必须 return 插件表或数组；
--      • 所有“非插件副作用配置”放 core/；
--      • 可在同一 import 层中定义多个文件（Lazy 自动收集）；
--      • 可按需禁用某层（注释 import）或在层内 enabled=false；
--      • 插件延迟加载尽量通过 event/ft/cmd/keys 控制；
--      • 尽量使用 opts 而非手写 config 函数。
--
---------------------------------------------------------------------------


vim.opt.rtp:prepend(lazypath)
require("lazy").setup({
    spec = {
        --{ import = "plugins" },
        { import = "plugins.lsp" },
        { import = "plugins.edit" },
        { import = "plugins.format" },
        --{ import = "plugins.diagnostics" },
        { import = "plugins.completion" },
        --{ import = "plugins.dap" },
        --{ import = "plugins.search" },
        { import = "plugins.ui" },
        { import = "plugins.git" },
        { import = "plugins.lang" },
        { import = "plugins.treesitter" },
    },
    install = { colorscheme = { "tokyonight", "catppuccin" } },
    checker = {
        enabled = true,
        notify = false,    -- 静默，不弹出通知
        frequency = 86400, -- 每 24 小时检查一次
    },
})


-- LSP
--require("LSP.init")
