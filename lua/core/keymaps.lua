-- Key mappings
local map = vim.keymap.set
local opts = { noremap = true, silent = true }
-- 使用 vim.keymap.set 设置映射
for _, mode in ipairs({ "v", "n" }) do
    map(mode, "<C-x>", "<Nop>", opts)

    map(mode, "<C-S-A>", "<C-x>", opts)

    -- 系统剪切板
    map(mode, "<Leader>y", '"+y', opts)
    map(mode, "<Leader>p", '"+p', opts)

    map(mode, "<A-d>", '"_d', opts)
end


-- 不需要禁用，会自动覆盖
-- map("", "<C-q>", "<Nop>")
map("v", "g<C-x>", "<Nop>", opts)
map("v", "g<C-S-A>", "g<C-x>", opts)

-- Visual mode J/K for moving code blocks
-- 向下移动选中文本
map("v", "J", ":move '>+1<CR>gv=gv", opts)
-- 向上移动选中文本
map("v", "K", ":move '<-2<CR>gv=gv", opts)

-- format
-- -- 使用 LSP 的格式化
--_G.lsp_format = function()
--    vim.lsp.buf.format({
--        filter = function(client)
--            -- 如果是 null-ls，则调用
--            if client.name == "null-ls" then
--                return true
--            end
--            return client.supports_method("textDocument/formatting")
--        end,
--        async = true,
--    })
--end


map("n", "<C-h>", "<C-w>h", opts)
map("n", "<C-j>", "<C-w>j", opts)
map("n", "<C-k>", "<C-w>k", opts)
map("n", "<C-l>", "<C-w>l", opts)

-- C-x

map('n', '`', function()
    vim.cmd [[Switch]]
end, { desc = 'Switch strings' })
map("n", "<C-x>t", ":enew<CR>", { desc = "New buffer" })
map("n", "<C-x>T", ":tabnew<CR>", { desc = "New tabpage (workspace)" })
map("n", "<C-x><Tab>", ":tabnext<CR>", { desc = "Next tabpage" })
map("n", "<C-x><S-Tab>", ":tabprevious<CR>", { desc = "Prev tabpage" })

map("n", "<C-x>3", function()
    vim.cmd.vsplit()
end, { desc = "Split right" })

map("n", "<C-x>2", function()
    vim.cmd.split()
end, { desc = "Split below" })
