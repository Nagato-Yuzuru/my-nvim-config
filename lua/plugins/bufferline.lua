require("bufferline").setup(
    {
        options = {
            numbers = "buffer_id",
            diagnostics = "nvim_lsp",
            separator_style = "slant",
        },
    }
)

local opts = { noremap = true, silent = true}
local map = vim.api.nvim_set_keymap

map("n", "<C-x>n", ":BufferLineCycleNext<CR>", opts)
map("n", "<C-x>p", ":BufferLineCyclePrev<CR>", opts)

map("n", "<C-x>0", ":bdelete<CR>", opts)

map("n", "<C-x>k", ":BufferLinePickClose<CR>", opts)     -- 弹出 buffer 列表让你选择关闭
map("n", "<C-x>o", ":BufferLinePick<CR>", opts)          -- 弹出 buffer 列表让你选择跳转

