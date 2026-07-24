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

-- 全局浮窗边框：hover / signature help / 诊断浮窗等原生浮窗默认无边框（方角），
-- winborder 给所有"未显式指定 border"的浮窗统一加圆角，是边框风格的单一真相
-- （诊断浮窗的 border 由此处提供，见 core/diagnostic.lua）。各插件浮窗
-- （blink.cmp / goto-preview / snacks / noice / which-key / trouble 等）都显式
-- 设了自己的 border，winborder 只作用于未指定者，故不会双重边框。
vim.o.winborder = "rounded"

-- :s 增量预览 — 输入 :s/old/new 时实时高亮所有匹配并开 split 列出影响行，
-- <CR> 落地、<Esc> 取消。零依赖、原生 vim 正则不变。
vim.opt.inccommand = "split"

-- K 在非 LSP buffer / hover popup 里的 fallback：默认 :Man 对现代工具几乎必 miss
-- （ty/tsserver/gopls 等都不提供 man page），改走 :help 更契合我们的日常栈
vim.opt.keywordprg = ":help"

vim.opt.expandtab = true -- 将 Tab 键转换为空格
vim.opt.shiftwidth = 4 -- 设置缩进宽度为 4
vim.opt.softtabstop = 4 -- 设置 Tab 键行为为 4 个空格
vim.opt.tabstop = 4 -- 设置显示 Tab 的宽度为 4

-- 剪贴板不自动同步的决定（及 why）在 init.lua 顶部

-- 行号颜色在 tokyonight on_highlights 中统一设置

-- yank 高亮：Neovim 从不默认启用，需要自己接 TextYankPost + vim.hl.on_yank()
-- （同 runtime example_init.lua 的建议做法）
vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("UserYankHighlight", { clear = true }),
	callback = function() vim.hl.on_yank() end,
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
		-- OpenTofu 独有扩展名，归到 terraform 系 ft 以复用同一套
		-- treesitter parser / tofu-ls / tofu_fmt（.tofu 同名时覆盖 .tf，见 OpenTofu 文档）
		tofu = "terraform",
		tofuvars = "terraform-vars",
		gotmpl = "gotmpl",
		mdx = "markdown.mdx",
		-- 独立 .promql 文件（少见——多数 PromQL 内嵌 yaml 规则的 expr:）：给
		-- promql LSP（lsp/promql_ls.lua）+ treesitter promql parser 一个可挂载的
		-- ft。yaml 里的 PromQL 走 expr: 注入（queries/yaml/injections.scm），不靠它。
		promql = "promql",
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
