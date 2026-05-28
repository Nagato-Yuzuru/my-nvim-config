-- lua/plugins/edit/eyeliner.lua
-- eyeliner.nvim: quickscope-style hints — highlights the best-jump
-- character in each word on the current line when f/F/t/T is pressed.
-- Mirrors `set quickscope` + `let g:qs_highlight_on_keys = ['f','F','t','T']`
-- on the IdeaVim side (.ideavimrc).
--
-- Owns f/F/t/T — flash.nvim's modes.char is disabled in motion.lua to
-- avoid keymap shadowing (see the comment block at the top of that file).

return {
	{
		"jinh0/eyeliner.nvim",
		-- Lazy-load on the keys eyeliner intercepts. lazy.nvim will run
		-- the plugin's setup before pressing f triggers the keymap.
		keys = {
			{ "f", mode = { "n", "x", "o" }, desc = "eyeliner f" },
			{ "F", mode = { "n", "x", "o" }, desc = "eyeliner F" },
			{ "t", mode = { "n", "x", "o" }, desc = "eyeliner t" },
			{ "T", mode = { "n", "x", "o" }, desc = "eyeliner T" },
		},
		opts = {
			-- The whole point: no always-on highlights. Hints only appear
			-- the moment you press f/F/t/T, and clear on CursorMoved.
			highlight_on_key = true,
			-- Keep other chars at normal brightness; the colored hint is
			-- contrast enough without dimming everything else.
			dim = false,
			default_keymaps = true,
		},
	},
}
