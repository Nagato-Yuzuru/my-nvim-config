-- Set language and appearance

pcall(vim.cmd, "language messages en_US.UTF-8")
vim.opt.langmenu = "en_US.UTF-8"

vim.opt.mouse = "nvchr"
vim.opt.cursorline = true
vim.opt.number = true
vim.opt.termguicolors = true

vim.opt.expandtab = true -- 将 Tab 键转换为空格
vim.opt.shiftwidth = 4 -- 设置缩进宽度为 4
vim.opt.softtabstop = 4 -- 设置 Tab 键行为为 4 个空格
vim.opt.tabstop = 4 -- 设置显示 Tab 的宽度为 4
--vim.opt.clipboard = "unnamedplus"

vim.api.nvim_set_hl(0, "LineNr",        { fg = "#dddddd" })
vim.api.nvim_set_hl(0, "CursorLineNr",  { fg = "#ff996c" })