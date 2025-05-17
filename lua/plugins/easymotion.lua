-- ~/.config/nvim/lua/plugins/easymotion.lua
local map = vim.keymap.set
-- 方向键映射
map("n", "<Leader><Leader>h", "<Plug>(easymotion-linebackward)")
map("n", "<Leader><Leader>l", "<Plug>(easymotion-lineforward)")
map("n", "<Leader><Leader>j", "<Plug>(easymotion-j)")
map("n", "<Leader><Leader>k", "<Plug>(easymotion-k)")

-- 保持列位置（不要跳到行首）
vim.g.EasyMotion_startofline = 0

map("n", "f", "<Plug>(easymotion-bd-f)", { noremap = false })
map("n", "t", "<Plug>(easymotion-bd-t)", { noremap = false })
map("n", "s", "<Plug>(easymotion-s2)", { noremap = false })
