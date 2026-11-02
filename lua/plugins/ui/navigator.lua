-- plugins/ui/navigator.lua
-- <C-h/j/k/l>：先在 nvim 窗口间移动，到边缘再把焦点交给外层复用器的相邻 pane。
-- 外层复用器按环境选一次：$TMUX 优先（Rex pane 里再开 tmux 时，tmux 才是
-- nvim 的直接外层），否则 $REX_SESSION 走 Rex，都没有时 TmuxNavigate* 退化为
-- 纯 wincmd。
--
-- 只做 nvim → 复用器 一个方向：复用器侧不绑无前缀的 C-hjkl（shell / TUI 要用），
-- 回到 nvim 用复用器自己的前缀键（Rex：~/.config/rex/keys/core.lua 的 prefix h/C-h）。
-- 所以 rex-navigator 只装 nvim 半边，它 README 里的 Rex 端 companion 模块不装。
-- nvim-only：.ideavimrc 的 Window / split navigation 注释块记录了 IDE 侧只覆盖
-- 编辑器分屏这一半。

local function set(var) return (vim.env[var] or "") ~= "" end
local mux = (not set("TMUX") and set("REX_SESSION")) and "Rex" or "Tmux"

local function nav(key, dir)
	return { key, "<cmd>" .. mux .. "Navigate" .. dir .. "<cr>", desc = mux .. ": navigate " .. dir:lower() }
end

return {
	{
		"christoomey/vim-tmux-navigator",
		-- 关掉插件自带映射：它在 $TMUX 内会注册 terminal-mode 的 <C-h/j/k/l>
		-- tnoremap，RHS 是 "\<C-w>:\<C-U> Tmux..."——那是 Vim :terminal 的
		-- termwinkey 语法，nvim 没有，整串按键被原样喂给 shell（C-w 删词、
		-- C-u 清行、再打出 "TmuxNavigateLeft" 回车）。也违反 toggleterm.lua
		-- 文件头的裸 shell 设计：Terminal-mode 不设导航 tmap，<C-]> 出来再走
		-- 下面的 normal-mode 映射（由 keys 提供，不依赖插件默认值）。
		init = function() vim.g.tmux_navigator_no_mappings = 1 end,
		cmd = {
			"TmuxNavigateLeft",
			"TmuxNavigateDown",
			"TmuxNavigateUp",
			"TmuxNavigateRight",
			"TmuxNavigatePrevious",
		},
		keys = {
			nav("<c-h>", "Left"),
			nav("<c-j>", "Down"),
			nav("<c-k>", "Up"),
			nav("<c-l>", "Right"),
			-- Rex 没有"上一个 pane"，Rex 里退化为 wincmd p
			{ "<c-\\>", "<cmd>TmuxNavigatePrevious<cr>", desc = "Tmux: navigate previous" },
		},
	},
	{
		"baggiponte/rex-navigator.nvim",
		-- 早期插件 + Rex beta API：钉 commit，:Lazy update 时人工复查
		commit = "09c8da1c2696bdabbf37a773fbe8ee8779c9b8c1",
		cmd = { "RexNavigateLeft", "RexNavigateDown", "RexNavigateUp", "RexNavigateRight" },
		-- 键由上面的 keys 统一分派；terminal=false 同 vim-tmux-navigator 的理由
		opts = { mappings = false, terminal = false },
	},
}
