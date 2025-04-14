-- ~/.config/nvim/lua/plugins/easymotion.lua

-- 方向键映射
vim.keymap.set("n", "<Leader><Leader>h", "<Plug>(easymotion-linebackward)")
vim.keymap.set("n", "<Leader><Leader>l", "<Plug>(easymotion-lineforward)")
vim.keymap.set("n", "<Leader><Leader>j", "<Plug>(easymotion-j)")
vim.keymap.set("n", "<Leader><Leader>k", "<Plug>(easymotion-k)")

-- 保持列位置（不要跳到行首）
vim.g.EasyMotion_startofline = 0
