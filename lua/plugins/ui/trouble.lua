return {
	"folke/trouble.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	-- 让任何 :Trouble * 调用都能触发 lazy-load —— 防止其它插件
	-- （如 todo-comments 的 :TodoTrouble 走 :Trouble todo）在 trouble
	-- 还没加载时撞 E492。keys 触发器只覆盖具体快捷键，不覆盖命令调用。
	cmd = "Trouble",
	opts = {
		focus = true,
		follow = false, -- 不自动跟随光标跳转，需手动确认（<cr> / l）
		auto_preview = true, -- 光标移动时自动显示浮窗预览
		preview = {
			type = "float",
			relative = "editor",
			border = "rounded",
			title = "Preview",
			size = { width = 0.7, height = 0.4 },
			position = { 0.5, 0.5 },
		},
		win = {
			position = "bottom",
			height = 10,
			wo = {
				wrap = true,
			},
		},
		-- Move trouble's "toggle preview popup" from `p` to `<A-p>` to
		-- match snacks-explorer (plugins/ui/snacks.lua: `["<A-p>"] =
		-- "preview_toggle"`). Same key, same semantics in both sidebar
		-- tools — one set of muscle memory.
		--
		-- The default `p` is freed up; we don't repurpose it here so it
		-- falls through to whatever vim-default applies in the trouble
		-- list buffer (effectively no-op).
		--
		-- We do **not** add a focus-into-preview binding. trouble's
		-- design treats preview as ephemeral — it's auto-closed on list
		-- WinLeave (trouble/view/init.lua:133-146). Working around that
		-- needs autocmd-suppression hacks plus, ideally, force-scratch
		-- to keep the preview read-only when focused; the latter is too
		-- invasive (replaces trouble's Preview.create wholesale). For
		-- "browse / yank context", trouble's intended path is `<CR>`
		-- to commit + `<C-o>` to return.
		---@type table<string, trouble.Action.spec|false>
		keys = {
			p = false, -- disable default; rebound below.
			["<A-p>"] = "preview",
		},
	},
	keys = {
		{
			"<leader>vP",
			"<cmd>Trouble diagnostics toggle filter.buf=0 focus=false<cr>",
			desc = "Buffer Diagnostics (Trouble)",
		},
		{
			"gr",
			"<cmd>Trouble lsp_references toggle<cr>",
			desc = "LSP References (Trouble)",
		},
	},
}
