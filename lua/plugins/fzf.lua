-- 设置文件相关的快捷键
vim.api.nvim_set_keymap('n', '<leader>F', ':Files<CR>', { noremap = true, silent = true })        -- <leader>f 启动文件搜索
vim.api.nvim_set_keymap('n', '<leader>fb', ':Buffers<CR>', { noremap = true, silent = true })      -- <leader>b 切换缓冲区
vim.api.nvim_set_keymap('n', '<leader>fh', ':History<CR>', { noremap = true, silent = true })      -- <leader>h 命令历史搜索
vim.api.nvim_set_keymap('n', '<leader>ft', ':Tags<CR>', { noremap = true, silent = true })         -- <leader>t 启动标签搜索
vim.api.nvim_set_keymap('n', '<leader>fl', ':Lines<CR>', { noremap = true, silent = true })        -- <leader>l 查找行

