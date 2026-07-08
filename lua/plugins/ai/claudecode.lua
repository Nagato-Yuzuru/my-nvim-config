return {
	{
		"coder/claudecode.nvim",
		-- Pinned by commit on purpose: the WebSocket IDE protocol is
		-- reverse-engineered from the official Claude Code editor extensions, and
		-- release tags lag `main` by months — so a bump can shift wire behaviour
		-- under you. Re-review the diff on `:Lazy update` (same policy as
		-- go-deep.nvim). Bump = read what changed, don't blind-update.
		commit = "2390c6e45c4789072c293ac69de051d169668b29",
		-- Load at startup rather than on first keypress: `auto_start` writes the
		-- lockfile that `claude --ide` / the `/ide` picker discovers, so the WS
		-- server must already be up by the time you reach the tmux pane. The keys
		-- below are just the visible surface; they don't gate the server.
		event = "VeryLazy",
		opts = {
			-- tmux two-pane workflow: nvim owns ONLY the WS server + lockfile
			-- (~/.claude/ide/<port>.lock); `claude` runs in the sibling pane and
			-- attaches via its `/ide` picker. Manual `/ide` selection is also how
			-- multiple nvim instances are disambiguated (listed by workspace).
			-- Flip provider to "snacks"/"native" to instead run claude *inside*
			-- nvim — that gives deterministic 1:1 pairing (the plugin injects
			-- CLAUDE_CODE_SSE_PORT) but drops the two-pane setup.
			terminal = { provider = "none" },
			auto_start = true, -- write the lockfile at startup so `/ide` can find us
			track_selection = true, -- broadcast cursor/selection, like an IDE sidebar
			diff_opts = { layout = "vertical" }, -- "unified" = VS Code-style single buffer
		},
		-- none-mode binds only the *protocol* actions, one key per verb — the
		-- second key is the verb's first letter: Send / add Buffer / Accept /
		-- Deny / Close / Info (`aa`=accept earns the double-tap as the most
		-- frequent action). Upstream's terminal toggle/focus/model/resume/continue
		-- defaults are omitted (they manage an in-nvim claude we don't run); we
		-- reuse `<leader>ac` — upstream's terminal-toggle — for close-diffs.
		keys = {
			{ "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Claude: send selection" },
			{
				"<leader>ab",
				function() vim.cmd("ClaudeCodeAdd " .. vim.fn.fnameescape(vim.fn.expand("%:p"))) end,
				desc = "Claude: add buffer",
			},
			{ "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Claude: accept diff" },
			{ "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Claude: deny diff" },
			{ "<leader>ac", "<cmd>ClaudeCodeCloseAllDiffs<cr>", desc = "Claude: close all diffs" },
			{ "<leader>ai", "<cmd>ClaudeCodeStatus<cr>", desc = "Claude: connection info" },
		},
	},
}
