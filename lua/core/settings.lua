-- Set language and appearance

vim.opt.langmenu = "en_US.UTF-8"
vim.cmd("language messages en_US.UTF-8")
vim.opt.mouse = ""
vim.opt.cursorline = true
vim.opt.number = true

vim.cmd [[
  highlight LineNr guifg=#dddddd
  highlight CursorLineNr guifg=#ff996c
]]
