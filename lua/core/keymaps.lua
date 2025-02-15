-- Key mappings
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- 使用 vim.keymap.set 设置映射
for _, mode in ipairs({'v', 'n'}) do
  map(mode, '<C-x>', '<Nop>', { noremap = true, silent = true })
  map(mode, '<C-S-A>', '<C-x>', { noremap = true, silent = true })
end

map('v', 'g<C-x>', '<Nop>', { noremap = true, silent = true })
map('v', 'g<C-S-A>', 'g<C-x>', { noremap = true, silent = true })

-- Visual mode J/K for moving code blocks
-- 向下移动选中文本
map('v', 'J', ":move '>+1<CR>gv=gv", { noremap = true, silent = true })

-- 向上移动选中文本
map('v', 'K', ":move '<-2<CR>gv=gv", { noremap = true, silent = true })

