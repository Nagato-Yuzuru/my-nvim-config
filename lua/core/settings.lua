-- Set language and appearance

vim.opt.langmenu = "en_US.UTF-8"
vim.cmd("language messages en_US.UTF-8")
vim.opt.mouse = ""
vim.opt.cursorline = true
vim.opt.number = true
vim.opt.termguicolors = true

vim.o.expandtab = true     -- 将 Tab 键转换为空格
vim.o.shiftwidth = 4       -- 设置缩进宽度为 4
vim.o.softtabstop = 4      -- 设置 Tab 键行为为 4 个空格
vim.o.tabstop = 4          -- 设置显示 Tab 的宽度为 4

vim.cmd [[
  highlight LineNr guifg=#dddddd
  highlight CursorLineNr guifg=#ff996c
]]
