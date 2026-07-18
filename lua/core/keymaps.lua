-- Key mappings
local map = vim.keymap.set
local opts = { noremap = true, silent = true }
-- 每条映射都必须带 desc：which-key 的 filter 会把没有 desc 的映射整条丢弃
-- （见 plugins/ui/which-key.lua 的 filter）。这里在共享的 noremap/silent 基底
-- 上逐条补 desc，而不是复用裸 opts。
local function o(desc) return vim.tbl_extend("force", opts, { desc = desc }) end
-- 使用 vim.keymap.set 设置映射
for _, mode in ipairs({ "v", "n" }) do
	map(mode, "<C-x>", "<Nop>", o("Disable <C-x> (chord prefix)"))

	map(mode, "<C-S-A>", "<C-x>", o("Decrement number"))

	-- 系统剪切板
	map(mode, "<Leader>y", '"+y', o("Yank to system clipboard"))
	map(mode, "<Leader>p", '"+p', o("Paste from system clipboard"))

	map(mode, "<A-d>", '"_d', o("Delete (black-hole register)"))
end

map("v", "g<C-x>", "<Nop>", o("Disable g<C-x>"))
map("v", "g<C-S-A>", "g<C-x>", o("Decrement sequentially"))

-- Visual mode J/K for moving code blocks
-- 向下移动选中文本
map("v", "J", ":move '>+1<CR>gv=gv", o("Move selection down"))
-- 向上移动选中文本
map("v", "K", ":move '<-2<CR>gv=gv", o("Move selection up"))

-- 格式化由 conform.nvim 负责（plugins/format/conform.lua，<leader>ff），不走
-- vim.lsp.buf.format。

-- <C-h/j/k/l> 窗口移动由 vim-tmux-navigator 提供（plugins/ui/tmux.lua），
-- 它兼顾 nvim 内部窗口 + tmux pane 切换。此处不再重复绑定，否则会被
-- 插件加载时覆盖，等于死代码。

-- kitty keyboard protocol 下 Shift+letter 以 <S-X> 形式到达
map("n", "<C-w><S-H>", "<cmd>wincmd H<CR>", { desc = "Move window far left" })
map("n", "<C-w><S-J>", "<cmd>wincmd J<CR>", { desc = "Move window far down" })
map("n", "<C-w><S-K>", "<cmd>wincmd K<CR>", { desc = "Move window far up" })
map("n", "<C-w><S-L>", "<cmd>wincmd L<CR>", { desc = "Move window far right" })
map("n", "<C-w><S-R>", "<cmd>wincmd R<CR>", { desc = "Rotate windows up" })

-- ` (Switch under cursor) 由 plugins/lang/markdown.lua 的 switch.vim
-- spec 通过 lazy `keys =` 注册——按 ` 时按需载入插件并执行 :Switch。
-- 不在这里全局 map 避免插件未加载时撞 E492。

-- C-x — workspace 层前缀：只管 buffer / tab / terminal / minimap。
-- 窗格生命周期一律走 vim 原生 <C-w>（分屏 s/v、关闭 c/q、only o、
-- <C-w>T 抽去新 tab）——IdeaVim 引擎同样原生实现这组键，是两边唯一
-- 零配置同步的语法层。emacs 式 <C-x>2/3 分屏键已退役，勿再往
-- <C-x> 加窗格键（判据：看动词作用的对象是 window 还是 tab/buffer）。

map("n", "<C-x>t", ":enew<CR>", { desc = "New buffer" })
map("n", "<C-x>T", ":tabnew<CR>", { desc = "New tabpage (workspace)" })
map("n", "<C-x><Tab>", ":tabnext<CR>", { desc = "Next tabpage" })
map("n", "<C-x><S-Tab>", ":tabprevious<CR>", { desc = "Prev tabpage" })
map("n", "<C-x>X", ":tabclose<CR>", { desc = "Close tabpage" })

-- Rename tab. nvim-only: JetBrains 的 tab 是 file-level（≈ buffer），没有
-- workspace 容器的语义可以重命名；asymmetry 在 .ideavimrc 里有注释。
-- 名字存在 t:tabname，bufferline custom_areas 渲染（plugins/ui/bufferline.lua）。
map("n", "<C-x>R", function()
	vim.ui.input({ prompt = "Tab name: ", default = vim.t.tabname or "" }, function(input)
		if input == nil then
			return
		end
		if input ~= "" then
			vim.t.tabname = input
		elseif vim.t.tabname then
			-- vim.t.x = nil 走 nvim_tabpage_del_var，未设过会抛——只有存在时才清
			vim.t.tabname = nil
		end
		vim.cmd("redrawtabline")
	end)
end, { desc = "Rename current tab" })

vim.keymap.set(
	"c",
	"<C-x><C-e>",
	function() return vim.api.nvim_replace_termcodes(vim.o.cedit, true, true, true) end,
	{ expr = true, desc = "Open command-line window (cedit)" }
)
