-- Set language and appearance

pcall(vim.cmd, "language messages en_US.UTF-8")
vim.opt.langmenu = "en_US.UTF-8"

vim.opt.mouse = "nvchr"
vim.opt.cursorline = true
vim.opt.number = true
vim.opt.termguicolors = true
vim.opt.showmode = false -- lualine 已显示 mode
vim.opt.ruler = false -- lualine 已显示位置
vim.opt.cmdheight = 0 -- noice 接管 cmdline，隐藏原生命令行区域

-- K 在非 LSP buffer / hover popup 里的 fallback：默认 :Man 对现代工具几乎必 miss
-- （pyright/tsserver/gopls 等都不提供 man page），改走 :help 更契合我们的日常栈
vim.opt.keywordprg = ":help"

vim.opt.expandtab = true -- 将 Tab 键转换为空格
vim.opt.shiftwidth = 4 -- 设置缩进宽度为 4
vim.opt.softtabstop = 4 -- 设置 Tab 键行为为 4 个空格
vim.opt.tabstop = 4 -- 设置显示 Tab 的宽度为 4
--vim.opt.clipboard = "unnamedplus"

-- 行号颜色在 tokyonight on_highlights 中统一设置

-- yank 高亮（Neovim 0.12 不再默认启用）
vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("UserYankHighlight", { clear = true }),
	callback = function()
		vim.hl.on_yank()
	end,
})

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- filetype detection（复合/非标准 filetype，供 lsp/*.lua 中声明的 filetypes 使用）
vim.filetype.add({
	pattern = {
		["docker%-compose%.ya?ml"] = "yaml.docker-compose",
		["%.?[Dd]ockerfile%..+"] = "dockerfile",
	},
	extension = {
		tfvars = "terraform-vars",
		gotmpl = "gotmpl",
		mdx = "markdown.mdx",
	},
	filename = {
		["go.work"] = "gowork",
	},
})

-- diff
vim.opt.diffopt = {
	"internal",
	"filler", -- 显示空行以对齐
	"closeoff", -- 如果一个窗口关闭，同时也关闭 diff 模式
	"hiddenoff",
	"algorithm:histogram",
	"indent-heuristic", -- 优化缩进显示的逻辑
}
