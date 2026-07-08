vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- 不自动跟系统剪贴板同步；用 <leader>y / <leader>p 显式走 "+ 寄存器
-- vim.opt.clipboard = "unnamedplus"

require("core.options")
require("core.keymaps")
require("core.hlsearch").setup() -- auto-nohlsearch，详见 core/hlsearch.lua 顶部注释

-- Firenvim 早分支：浏览器拉起的 nvim 必须在 ~3s 内 attach UI，否则报
-- "Neovim died without answering"。这里关掉启动期的 Mason 自动安装
-- （mason_ensure.lua 认这个环境变量），并精简浮窗里的 UI 噪音。
if vim.g.started_by_firenvim then
	vim.env.NO_AUTO_INSTALL = "1"
	vim.opt.laststatus = 0
	vim.opt.showtabline = 0
	vim.opt.cmdheight = 1
	vim.opt.signcolumn = "no"
	vim.opt.number = false
	vim.opt.relativenumber = false
	vim.opt.wrap = true
	vim.opt.linebreak = true
	vim.opt.guifont = "JetBrainsMono Nerd Font:h14"
	-- 实时回写到网页 textarea
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		callback = function() vim.cmd("silent! write") end,
	})
end

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
		{ import = "plugins.ai" },
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

require("core.lsp").setup()
require("core.diagnostic")
require("plugins.schemas.picker").setup()
