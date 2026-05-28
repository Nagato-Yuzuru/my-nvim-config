-- lua/plugins/edit/registers.lua
-- vim-peekaboo: floating preview of register contents when pressing
-- `"` (normal/visual), `@` (normal), or `<C-r>` (insert/command).
--
-- This is the original plugin that IdeaVim's `set peekaboo` emulates
-- (.ideavimrc line 51) — so both editors share identical behavior.
-- Vimscript, but small and well-maintained; no Lua rewrite has stayed
-- maintained (tversteeg/registers.nvim has been deleted, forks are stale).

return {
	{
		"junegunn/vim-peekaboo",
		-- Lazy-load on the exact triggers peekaboo intercepts.
		keys = {
			{ '"', mode = { "n", "x" }, desc = "Peekaboo registers" },
			{ "@", mode = "n", desc = "Peekaboo registers (macro)" },
			{ "<C-r>", mode = { "i", "c" }, desc = "Peekaboo registers (insert)" },
		},
		init = function()
			-- Default delay before the popup appears (ms). 0 = instant; the
			-- plugin default 400ms feels sluggish when you already know which
			-- register you want.
			vim.g.peekaboo_delay = 0
		end,
	},
}
