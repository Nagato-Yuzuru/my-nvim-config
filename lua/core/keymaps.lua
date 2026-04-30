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

-- <C-h/j/k/l> 窗口移动由 vim-tmux-navigator 提供（plugins/ui/tmux.lua），
-- 它兼顾 nvim 内部窗口 + tmux pane 切换。此处不再重复绑定，否则会被
-- 插件加载时覆盖，等于死代码。

-- kitty keyboard protocol 下 Shift+letter 以 <S-X> 形式到达
map("n", "<C-w><S-H>", "<cmd>wincmd H<CR>", { desc = "Move window far left" })
map("n", "<C-w><S-J>", "<cmd>wincmd J<CR>", { desc = "Move window far down" })
map("n", "<C-w><S-K>", "<cmd>wincmd K<CR>", { desc = "Move window far up" })
map("n", "<C-w><S-L>", "<cmd>wincmd L<CR>", { desc = "Move window far right" })
map("n", "<C-w><S-R>", "<cmd>wincmd R<CR>", { desc = "Rotate windows up" })

-- C-x

map("n", "`", function()
	vim.cmd([[Switch]])
end, { desc = "Switch strings" })
map("n", "<C-x>t", ":enew<CR>", { desc = "New buffer" })
map("n", "<C-x>T", ":tabnew<CR>", { desc = "New tabpage (workspace)" })
map("n", "<C-x><Tab>", ":tabnext<CR>", { desc = "Next tabpage" })
map("n", "<C-x><S-Tab>", ":tabprevious<CR>", { desc = "Prev tabpage" })
map("n", "<C-x>X", ":tabclose<CR>", { desc = "Close tabpage" })

map("n", "<C-x>3", function()
	vim.cmd.vsplit()
end, { desc = "Split right" })

map("n", "<C-x>2", function()
	vim.cmd.split()
end, { desc = "Split below" })

vim.keymap.set("c", "<C-x><C-e>", function()
	return vim.api.nvim_replace_termcodes(vim.o.cedit, true, true, true)
end, { expr = true })
