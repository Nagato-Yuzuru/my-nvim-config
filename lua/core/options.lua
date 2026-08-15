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

-- 远端会话（ssh，含目标机 tmux 内）：强制 + 寄存器 copy 走 OSC52。
-- 为什么强制而不是等 0.10+ 的自动回落：自动回落要先向终端探测 OSC52 支持，
-- 探测穿 tmux 常无应答（:h clipboard-osc52 明言 multiplexer 会 inhibit 探测），
-- provider 解析走到头报 "No clipboard tool found"。g:clipboard 在解析顺序第一位，
-- 设了即短路探测；发出的 OSC52 由 tmux set-clipboard on 截获转发到外层终端
-- （与 tmux copy-mode 的透传同一条链路），落到人所在机器的剪贴板。
-- paste 刻意不走 OSC52 查询（穿 tmux 读到的是 tmux buffer 而非宿主机剪贴板，
-- 链路不应答还会阻塞等超时）：退化为读 unnamed 寄存器——<leader>y 过的内容
-- 可直接回贴；mac→远端方向走终端粘贴（Cmd-V，bracketed paste 直达 buffer）。
-- 门控查两个变量：tmux 默认 update-environment 含 SSH_CONNECTION 不含 SSH_TTY，
-- 只查后者会在目标机 tmux pane 里漏判。本机两者皆空，此块不执行，pbcopy 照旧。
if vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
	local osc52 = require("vim.ui.clipboard.osc52")
	local function paste_fallback() return { vim.fn.getreg('"', 1, true), vim.fn.getregtype('"') } end
	vim.g.clipboard = {
		name = "osc52-copy",
		copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
		paste = { ["+"] = paste_fallback, ["*"] = paste_fallback },
	}
end

-- 行号颜色在 tokyonight on_highlights 中统一设置

-- yank 高亮：Neovim 从不默认启用，需要自己接 TextYankPost + vim.hl.on_yank()
-- （同 runtime example_init.lua 的建议做法）
vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("UserYankHighlight", { clear = true }),
	callback = function() vim.hl.on_yank() end,
})

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- filetype detection 归语言域：plugins/lang/<x>.lua 经 tools/lang_registry 注册，
-- init.lua 在 lazy.setup() 之后统一 apply（单点 vim.filetype.add，见 lang_registry
-- 头注释）。本文件不再持有任何 ft 条目。

-- diff
vim.opt.diffopt = {
	"internal",
	"filler", -- 显示空行以对齐
	"closeoff", -- 如果一个窗口关闭，同时也关闭 diff 模式
	"hiddenoff",
	"algorithm:histogram",
	"indent-heuristic", -- 优化缩进显示的逻辑
}
