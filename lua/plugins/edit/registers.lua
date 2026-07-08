-- lua/plugins/edit/registers.lua
-- vim-peekaboo: floating preview of register contents when pressing
-- `"` (normal/visual), `@` (normal), or `<C-r>` (insert/command).
--
-- This is the original plugin that IdeaVim's `set peekaboo` emulates
-- (.ideavimrc emulated-plugins section) — so both editors share identical
-- behavior.
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
	},
}
