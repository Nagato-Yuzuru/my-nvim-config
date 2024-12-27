-- Lazy.nvim load
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- 推荐使用稳定版本
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
require("plugins.init")
