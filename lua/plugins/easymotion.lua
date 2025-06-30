-- ~/.config/nvim/lua/plugins/easymotion.lua
local map = vim.keymap.set
-- 方向键映射
mod = { "n", "o", "x" }
map(mod, "<Leader><Leader>h", "<Plug>(easymotion-linebackward)")
map(mod, "<Leader><Leader>l", "<Plug>(easymotion-lineforward)")
map(mod, "<Leader><Leader>j", "<Plug>(easymotion-j)")
map(mod, "<Leader><Leader>k", "<Plug>(easymotion-k)")

-- 保asdada asd持列位置（不要跳到行首）
vim.g.EasyMotion_move_highlight = 0
vim.g.EasyMotion_do_mapping = 0
vim.g.EasyMotion_smartcase = 1

vim.g.EasyMotion_startofline = 0

map(mod, "f", "<Plug>(easymotion-bd-f)", { noremap = false })
map(mod, "t", "<Plug>(easymotion-bd-t)", { noremap = false })
map(mod, "s", "<Plug>(easymotion-s2)", { noremap = false })
