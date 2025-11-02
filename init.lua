vim.g.mapleader = " "
vim.g.maplocalleader = ","

vim.opt.clipboard = "unnamedplus"

-- Lazynvim load
require("core.lazy")
-- Neovim configuration
require("core.settings")
require("core.keymaps")

-- LSP
require("LSP.init")
