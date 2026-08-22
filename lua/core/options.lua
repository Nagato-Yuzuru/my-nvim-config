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

-- + 寄存器的 provider 按环境选，分支顺序即优先级。设了 g:clipboard，nvim 就不再自动探测。
--
-- tmux 内的复制交给 tmux。`load-buffer -w` 存一份 buffer，再由 tmux 向此刻 attach 的客户端发
-- OSC 52。前提是 tmux ≥ 3.2，且 tmux.conf.local 里 set-clipboard on。
-- 不能按 SSH_* 来判断，因为 pane 的环境在它出生那一刻就定死了。session 在远端本地的 Ghostty
-- 里建好、之后从别的机器 ssh attach，旧 pane 里既没有 SSH_TTY 也没有 SSH_CONNECTION，nvim
-- 探测到 pbcopy，内容进的是远端自己的剪贴板。只有 tmux 知道此刻是谁 attach 着。-w 直达客户端
-- 不经 pane，pane 不在当前窗口也送得到。
-- 粘贴不用内建 tmux provider 的 `refresh-client -l`。Ghostty 的 clipboard-read 默认 ask，每次
-- 粘贴都弹框；终端没应答时拿到的只是 tmux 最新 buffer；over ssh 还有 50ms 的竞态。所以有
-- pbpaste 就用 pbpaste，本机行为不变；远端 Mac 上读到的是远端剪贴板，mac→远端方向走 Cmd-V。
-- 没有 pbpaste 的机器读 tmux 最新 buffer，<leader>y 过的和 copy-mode 复制的都能回贴。
--
-- ssh 但没有 tmux：复制走 OSC 52，终端直收。粘贴读 unnamed 寄存器，不发 OSC 52 查询，查询
-- 没应答会阻塞到超时。
--
-- 其余情况交给 nvim 默认探测，本机就是 pbcopy/pbpaste。
if vim.env.TMUX then
	local copy = { "tmux", "load-buffer", "-w", "-" }
	local paste = vim.fn.executable("pbpaste") == 1 and { "pbpaste" } or { "tmux", "save-buffer", "-" }
	vim.g.clipboard = {
		name = "tmux-copy",
		copy = { ["+"] = copy, ["*"] = copy },
		paste = { ["+"] = paste, ["*"] = paste },
	}
elseif vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
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
