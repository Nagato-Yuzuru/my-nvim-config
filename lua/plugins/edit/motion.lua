-- lua/plugins/edit/motion.lua
-- Flash.nvim: EasyMotion-style jump layout aligned with the IdeaVim side.
-- See ~/.config/nvim/.ideavimrc for mirror.
--
-- Layout:
--   <leader><leader>h/l   line-scoped word ← / →
--   <leader><leader>H/L   buffer-wide word ← / →   (word = \k, mirrors h/l)
--   <leader><leader>j/k   cross-line first-non-blank ↓ / ↑
--   <leader><leader>w/b/e line-scoped word motions
--   <leader><leader>W/B/E buffer-wide WORD motions (\S+)
--   <leader><leader>s     default Flash.jump (incremental search)
--   <leader><leader>/     explicit label search (mirrors IdeaVim AceAction)
--   <leader><leader>t/T   Flash treesitter / treesitter_search (Neovim only)
--   <leader><leader>.     repeat last Flash jump
--
-- Native keys enhanced (not overridden):
--   / ?          -> modes.search hooks in flash labels during regular search
--
-- f/F/t/T are intentionally NOT enhanced by flash here — eyeliner.nvim
-- (lua/plugins/edit/eyeliner.lua) owns those keys to provide quickscope-
-- style pre-press hints, matching IdeaVim's `set quickscope`. Flash's
-- char-mode keymaps would shadow eyeliner's (and vice versa), so only
-- one can win — we picked eyeliner for cross-editor parity.

---Build a vim regex that restricts matches to the cursor's current line.
---Called at keypress time so the line number is always fresh.
---@param pat string inner vim regex, e.g. [[\<\k]]
---@return string
local function line_only(pat) return [[\%]] .. vim.fn.line(".") .. [[l]] .. pat end

---Build a Flash.jump callback for a fixed-pattern label jump (Hop-style:
---no user input accepted, pattern is locked, labels appear immediately).
---@param pattern string|fun():string vim regex, or a thunk returning one
---@param search_opts table? merged into `search` (e.g. { forward = false })
---@param extra table? deep-merged onto the top-level jump opts
local function flash_pat(pattern, search_opts, extra)
	return function()
		local pat = type(pattern) == "function" and pattern() or pattern
		local opts = vim.tbl_deep_extend("force", {
			search = vim.tbl_extend("force", {
				mode = "search",
				max_length = 0,
				multi_window = false,
				wrap = false,
			}, search_opts or {}),
			pattern = pat,
		}, extra or {})
		require("flash").jump(opts)
	end
end

local MODE = { "n", "x", "o" }

return {
	{
		-- 个人 fork：上游在被标记的浮窗于 CmdlineLeave 时关闭后（blink.cmp 的
		-- cmdline 补全菜单套在 noice cmdline_popup 里就会触发）jump 报
		-- "Invalid window id"——flash 在打标时记 winid、跳转前不复验。fork 加了
		-- stale-winid guard（详见 commit ffd5c4c）。跟踪 branch 而非 pin commit，
		-- :Lazy update 会拉新 commit——更新时 re-review（同 go-deep.nvim 政策）；
		-- 上游修掉后退役此 fork。
		url = "https://github.com/Nagato-Yuzuru/flash.nvim",
		branch = "fix/motion-in-blink",
		event = "VeryLazy",
		---@type Flash.Config
		opts = {
			-- Full 52-letter pool: lowercase home/top/bottom rows, then the
			-- same rows uppercased. Flash assigns from left to right by
			-- proximity, so the first ~26 nearby matches still get the easy
			-- lowercase keys, and anything beyond that falls back to Shift+*
			-- instead of running out of labels.
			labels = "asdfghjklqwertyuiopzxcvbnm" .. "ASDFGHJKLQWERTYUIOPZXCVBNM",
			label = {
				-- Insert label instead of overlaying it, so the second char
				-- of each match stays visible.
				style = "inline",
				-- Explicit (already default) — keeps the above 52-char pool
				-- intact even if a future default changes.
				uppercase = true,
			},
			modes = {
				-- Hook `/` and `?` so labels appear next to every search match.
				search = { enabled = true },
				-- f/F/t/T are owned by eyeliner.nvim (see header comment).
				char = { enabled = false },
			},
		},
		keys = {
			-- ===== Line direction (words, current line) =====
			{
				"<leader><leader>h",
				flash_pat(function() return line_only([[\<\k]]) end, { forward = false }),
				mode = MODE,
				desc = "Flash ← word (line)",
			},
			{
				"<leader><leader>l",
				flash_pat(function() return line_only([[\<\k]]) end, { forward = true }),
				mode = MODE,
				desc = "Flash → word (line)",
			},

			-- ===== Buffer-wide word (mirror of h/l, word = \k not \S+) =====
			{
				"<leader><leader>H",
				flash_pat([[\<\k]], { forward = false }),
				mode = MODE,
				desc = "Flash ← word (buffer)",
			},
			{
				"<leader><leader>L",
				flash_pat([[\<\k]], { forward = true }),
				mode = MODE,
				desc = "Flash → word (buffer)",
			},

			-- ===== Cross-line lines (first non-blank of each line) =====
			{
				"<leader><leader>j",
				flash_pat([[^\s*\zs\S]], { forward = true }),
				mode = MODE,
				desc = "Flash ↓ lines",
			},
			{
				"<leader><leader>k",
				flash_pat([[^\s*\zs\S]], { forward = false }),
				mode = MODE,
				desc = "Flash ↑ lines",
			},

			-- ===== Line-scoped word motions (w/b/e) =====
			{
				"<leader><leader>w",
				flash_pat(function() return line_only([[\<\k]]) end, { forward = true }),
				mode = MODE,
				desc = "Flash w (line)",
			},
			{
				"<leader><leader>b",
				flash_pat(function() return line_only([[\<\k]]) end, { forward = false }),
				mode = MODE,
				desc = "Flash b (line)",
			},
			{
				"<leader><leader>e",
				flash_pat(function() return line_only([[\k\>]]) end, { forward = true }),
				mode = MODE,
				desc = "Flash e (line)",
			},

			-- ===== Buffer-wide WORD motions (non-whitespace blocks) =====
			{
				"<leader><leader>W",
				flash_pat([[\S\+]], { forward = true }),
				mode = MODE,
				desc = "Flash W",
			},
			{
				"<leader><leader>B",
				flash_pat([[\S\+]], { forward = false }),
				mode = MODE,
				desc = "Flash B",
			},
			{
				"<leader><leader>E",
				flash_pat([[\S\+]], { forward = true }, { jump = { pos = "end" } }),
				mode = MODE,
				desc = "Flash E",
			},

			-- ===== Incremental label jump =====
			{
				"<leader><leader>s",
				function() require("flash").jump() end,
				mode = MODE,
				desc = "Flash jump",
			},
			{
				"<leader><leader>/",
				function() require("flash").jump() end,
				mode = MODE,
				desc = "Flash label search",
			},

			-- ===== Treesitter (IdeaVim has no equivalent; intentionally unbound there) =====
			{
				"<leader><leader>t",
				function() require("flash").treesitter() end,
				mode = MODE,
				desc = "Flash Treesitter",
			},
			{
				"<leader><leader>T",
				function() require("flash").treesitter_search() end,
				mode = MODE,
				desc = "Flash Treesitter search",
			},

			-- ===== Repeat last Flash jump =====
			{
				"<leader><leader>.",
				function() require("flash").jump({ continue = true }) end,
				mode = MODE,
				desc = "Flash repeat",
			},
		},
	},
}
