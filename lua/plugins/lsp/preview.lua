-- goto-preview: 浮窗预览 LSP 跳转目标，不切换当前窗口。
-- 对位 JetBrains 的 ⌥Space (Quick Definition Lookup)，IdeaVim 那边用 IDE 原生
-- 快捷键即可，不需要绑定（见 .ideavimrc §Navigation 注释）。
--
-- 命名空间设计：gp* = "goto preview"，与已有 g* 跳转族（gd/gD/gi/gr）对偶。
--   gpd → preview definition       （配 gd）
--   gpD → preview type-definition  （配 gD）
--   gpi → preview implementation   （配 gi）
--   gpc → close-all preview windows（"panic exit"；预览窗内本来就能 q/<Esc> 关单层）
--
-- 故意不绑：
--   gP        默认 paste-with-cursor-end，覆盖代价大于收益；用 gpc 替代。
--   gpr       references 走 Trouble（gr，见 plugins/ui/trouble.lua），那条路径
--             支持持久浏览多候选，比浮窗合适。用户也明确表示更看实现而非引用。
--
-- 递归预览：plugin 默认 `stack_floating_preview_windows = true`，预览窗内再
-- gpd/gpD/gpi 会往深处压栈，gpc 一键收回所有层级。
return {
	"rmagatti/goto-preview",
	-- 这些键只在 LSP buffer 上有意义，但 plugin 启动时 LSP 可能还没 attach；
	-- 用 keys 做触发器即可，函数体内 require 时 plugin 才真正初始化。
	keys = {
		{
			"gpd",
			function() require("goto-preview").goto_preview_definition() end,
			desc = "LSP: Preview Definition",
		},
		{
			"gpD",
			function() require("goto-preview").goto_preview_type_definition() end,
			desc = "LSP: Preview Type Definition",
		},
		{
			"gpi",
			function() require("goto-preview").goto_preview_implementation() end,
			desc = "LSP: Preview Implementation",
		},
		{ "gpc", function() require("goto-preview").close_all_win() end, desc = "LSP: Close all preview windows" },
	},
	opts = {
		width = 120,
		height = 20,
		border = "rounded",
		-- 打开后自动把光标聚焦到预览窗（否则 j/k 还在主窗）。
		focus_on_open = true,
		-- 移动光标不自动关——递归预览要求"看完一个再看下一个"，自动关会打断。
		dismiss_on_move = false,
		-- 同文件预览也走浮窗，不复用主窗口（更接近 JetBrains ⌥Space 的体验）。
		same_file_float_preview = true,
		-- 显示预览窗标题（文件名），递归压栈时方便辨认层级。
		preview_window_title = { enable = true, position = "left" },
		-- references 这条路径我们没绑（见上方注释），保留 plugin 默认即可。
	},
	config = function(_, opts)
		require("goto-preview").setup(opts)

		-- Defensive guard at the LSP-response boundary.
		--
		-- Bug：当 LSP 返回的"非数组单 Location"对象缺少 uri/targetUri（部分
		-- server 在某些 typeDefinition / implementation 路径下会这样），
		-- lib.lua 里 get_config 会返回 nil URI，open_floating_win 的
		-- and-or 链 (`type(target)=="string" and uri_to_bufnr(target) or target`)
		-- 把 nil 透传到 set_title → nvim_buf_get_name(nil) → 抛
		-- "Invalid 'buf': Expected Lua number"。即使 preview_window_title.enable
		-- 设 false，set_title 依然会先调 nvim_buf_get_name 再判断 flag，
		-- 所以纯靠配置躲不掉。
		--
		-- 这里在 plugin / LSP 边界处加一道校验：拿不到合法 buffer 就 notify
		-- 退出，不静默吞掉（保持 loud failure 原则——把 server 异常告诉用户，
		-- 而不是装作没事）。一旦 upstream 修了 set_title 的 nil 处理，可以删。
		local lib = require("goto-preview.lib")
		local orig_open = lib.open_floating_win
		lib.open_floating_win = function(target, position, win_opts)
			if type(target) ~= "string" or target == "" then
				vim.notify("goto-preview: LSP returned no URI for target — skipping preview", vim.log.levels.WARN)
				return
			end
			local ok, bufnr = pcall(vim.uri_to_bufnr, target)
			if not ok or type(bufnr) ~= "number" then
				vim.notify("goto-preview: cannot resolve URI to buffer: " .. tostring(target), vim.log.levels.WARN)
				return
			end
			return orig_open(target, position, win_opts)
		end
	end,
}
