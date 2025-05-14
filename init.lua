vim.g.mapleader = ' '

vim.opt.clipboard = "unnamedplus"

-- Lazynvim load
require("core.lazy")
-- Neovim configuration
require("core.settings")
require("core.keymaps")

-- LSP
require("LSP.init")

