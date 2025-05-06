vim.g.mapleader = ' '
-- 设置 Leader 键为空格

vim.opt.clipboard = "unnamedplus"

-- Lazynvim load
require("core.lazy")
-- Neovim configuration
require("core.settings")
require("core.keymaps")

-- LSP
require("LSP.init")

