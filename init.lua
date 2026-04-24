vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- 不自动跟系统剪贴板同步；用 <leader>y / <leader>p 显式走 "+ 寄存器
-- vim.opt.clipboard = "unnamedplus"

require("core.options")
require("core.keymaps")

-- Lazy.nvim bootstrap
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end

vim.opt.rtp:prepend(lazypath)
require("lazy").setup({
	spec = {
		{ import = "plugins.lsp" },
		{ import = "plugins.edit" },
		{ import = "plugins.format" },
		{ import = "plugins.lint" },
		{ import = "plugins.completion" },
		{ import = "plugins.ui" },
		{ import = "plugins.git" },
		{ import = "plugins.lang" },
		{ import = "plugins.runtime" },
		{ import = "plugins.treesitter" },
	},
	rocks = {
		hererocks = true,
	},
	install = { colorscheme = { "tokyonight", "catppuccin" } },
	checker = {
		enabled = true,
		notify = false,
		frequency = 86400,
	},
})

require("core.lsp")
