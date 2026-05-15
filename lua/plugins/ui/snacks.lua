-- ============================================================
-- Helpers for snacks.explorer customization.
-- ============================================================

-- z* fold-style controls for the directory tree.
-- The cursor's "fold scope" is its directory: the dir itself when the
-- cursor is on a directory, or the containing dir when it's on a file
-- (matching the semantics of snacks's `explorer_close`).

---@param picker snacks.Picker
---@param item   snacks.picker.explorer.Item?
---@return snacks.picker.explorer.Node?
---@return string                          path that the node lives at
local function fold_target(picker, item)
	local Tree = require("snacks.explorer.tree")
	if not item then
		return Tree:find(picker:cwd()), picker:cwd()
	end
	local path = item.dir and item.file or vim.fs.dirname(item.file)
	return Tree:find(path), path
end

---@param node snacks.picker.explorer.Node?
local function open_recursive(node)
	local Tree = require("snacks.explorer.tree")
	if not node or not node.dir then
		return
	end
	node.open = true
	if not node.expanded then
		Tree:expand(node)
	end
	for _, child in pairs(node.children) do
		if child.dir then
			open_recursive(child)
		end
	end
end

---@param node snacks.picker.explorer.Node?
local function close_recursive(node)
	if not node or not node.dir then
		return
	end
	node.open = false
	node.expanded = false
	for _, child in pairs(node.children) do
		if child.dir then
			close_recursive(child)
		end
	end
end

---@param picker snacks.Picker
local function fold_refresh(picker)
	require("snacks.explorer.actions").update(picker, { refresh = true })
end

-- Wrap a "given a dir node, do X" function as a snacks action: resolve
-- fold_target, gate on node.dir, refresh after. Collapses the
-- boilerplate that's shared by all five `fold_*` actions below.
---@param fn fun(node: snacks.picker.explorer.Node, path: string)
---@return fun(picker: snacks.Picker, item: snacks.picker.explorer.Item?)
local function fold_action(fn)
	return function(picker, item)
		local node, path = fold_target(picker, item)
		if node and node.dir then
			fn(node, path)
			fold_refresh(picker)
		end
	end
end

-- ============================================================
-- Floating preview for snacks.explorer (CodeGlance / trouble-style).
-- ============================================================
-- Mirrors lua/plugins/ui/neominimap.lua: a closure-managed floating
-- window driven by lifecycle hooks. snacks's layout system is single-
-- rooted, so the built-in `preview` window can only live inside the
-- picker container or hijack the main editor (`preview = "main"`).
-- This module gives us a real `relative = "editor"` float decoupled
-- from the picker layout — equivalent to trouble's
-- `preview = { type = "float" }`.
--
-- Toggle keys aligned with trouble.nvim and the neominimap preview
-- popup (neominimap.lua:317-318):
--   <A-p>  toggle preview window (one-shot show / hide)
--   P      toggle auto-preview mode (on_change-driven follow vs frozen)
-- p stays bound to explorer_paste — file-manager paste convention wins.
--
-- Default: auto-preview OFF, no float on explorer entry. Press <A-p> to
-- snapshot the current item; press P to enable cursor-tracking. Rationale:
-- ambient auto-open caused spurious pops whenever on_change re-fired in
-- the background (matcher re-runs, focus returning from another picker).
-- Making the open explicit kills that whole class of surprises.
--
-- The preview buffer is a read-only scratch copy (not the user's real
-- file buffer):
--   * `modifiable` / `readonly` are buffer-local — setting them on the
--     real buffer would also lock it in the user's main window. Scratch
--     is the only way to make the preview window truly read-only
--     without polluting state elsewhere.
--   * `bufhidden = "wipe"` self-destructs the scratch when its only
--     window closes — no keymap-cleanup bookkeeping.
-- Cost: file content is duplicated in memory, bounded by the size caps
-- below (worst case ~few MB) — negligible. Treesitter is preserved by
-- copying the source filetype, which fires FileType on the scratch.

---@class explorer.Preview.State
---@field win  number floating window id
---@field buf  number scratch bufnr
---@field file string absolute file path

---@class explorer.Preview
---@field state     explorer.Preview.State?
---@field auto      boolean    when true, on_change updates the float live (default false)
---@field skip_file string?    one-shot suppression for the next on_change
local Preview = { state = nil, auto = false, skip_file = nil }
-- skip_file is set by commit_from_preview to absorb snacks's trailing-
-- edge throttle re-fire (snacks/util/init.lua:327 — _show_preview is
-- wrapped in a 60ms throttle that fires once more after the timer
-- expires if any throttled call was queued during the window). Without
-- this, pressing `l` to open a file made the float pop back up ~60ms
-- later. Cleared on every on_change call so it's at most one event old.

-- Size guards mirroring neominimap.lua:101/104. Above either threshold
-- we suppress the preview entirely. We deliberately do not try to
-- "render only the visible region" — partial buffer content breaks
-- treesitter parsing for many languages.
local PREVIEW_MAX_BYTES = 1024 * 1024
local PREVIEW_MAX_LINES = 30000

---@return boolean
local function valid_float()
	return Preview.state ~= nil and vim.api.nvim_win_is_valid(Preview.state.win)
end

local function close_float()
	if valid_float() then
		---@diagnostic disable-next-line: need-check-nil  -- valid_float() guards this
		pcall(vim.api.nvim_win_close, Preview.state.win, true)
	end
	Preview.state = nil
end

-- Cheap-and-correct binary detection: NUL-byte in the first 8KB. Same
-- heuristic as `git`, `grep -I`, and ripgrep — text essentially never
-- contains NUL; binaries (executables, images, archives, PDFs) almost
-- always have one in the first few KB.
--
-- Why we need this: vim.fn.readfile() on a binary file silently turns
-- NUL bytes into '\n' inside line strings, which then breaks
-- nvim_buf_set_lines (it rejects '\n' in replacement strings).
---@param file string
---@return boolean
local function is_binary(file)
	local f = io.open(file, "rb")
	if not f then
		return true -- unreadable → suppress preview
	end
	local chunk = f:read(8192)
	f:close()
	return chunk ~= nil and chunk:find("\0", 1, true) ~= nil
end

-- Read the file into a fresh read-only scratch buffer.
--
-- We deliberately avoid `vim.fn.bufadd(file)`: bufadd creates a
-- permanent entry in the buffer list, but the preview is supposed to
-- be ephemeral. Previewing N files would leave N entries in `:ls` even
-- after the picker closes.
--
-- Strategy:
--   * If the file is already loaded somewhere, copy lines from that
--     buffer — preserves unsaved edits and existing filetype.
--   * Otherwise, read from disk via vim.fn.readfile() and detect the
--     filetype with vim.filetype.match — no buffer-list pollution.
--
-- Treesitter starts on the scratch via the FileType autocmd, fired by
-- the final `vim.bo[buf].filetype = ft` assignment.
---@param file string
---@return number? bufnr  scratch bufnr; nil for binary / oversized / unreadable.
local function load_scratch(file)
	local stat = vim.uv.fs_stat(file)
	if not stat or stat.type ~= "file" or stat.size > PREVIEW_MAX_BYTES then
		return nil
	end
	if is_binary(file) then
		return nil
	end

	local source_lines, ft
	local existing = vim.fn.bufnr(file, false) -- false = don't create
	if existing ~= -1 and vim.api.nvim_buf_is_loaded(existing) then
		source_lines = vim.api.nvim_buf_get_lines(existing, 0, -1, false)
		ft = vim.bo[existing].filetype
		if ft == "" then
			ft = vim.filetype.match({ filename = file }) or ""
		end
	else
		local ok, lines = pcall(vim.fn.readfile, file)
		if not ok or not lines then
			return nil
		end
		source_lines = lines
		ft = vim.filetype.match({ filename = file }) or ""
	end
	if #source_lines > PREVIEW_MAX_LINES then
		return nil
	end

	local buf = vim.api.nvim_create_buf(false, true)
	-- Defensive pcall: even with the binary guard above, exotic files
	-- (UTF-16 with NUL past the first 8KB, weird newline encodings) can
	-- still produce lines that nvim_buf_set_lines rejects. Bail cleanly.
	local ok = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, source_lines)
	if not ok then
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
		return nil
	end
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.bo[buf].readonly = true
	-- filetype LAST: assignment fires FileType, which starts treesitter
	-- and any ftplugin.
	if ft ~= "" then
		vim.bo[buf].filetype = ft
	end
	return buf
end

-- Geometry: hardcoded percentages for v1. Sidebar is 40 cols wide on
-- the left; place the float starting at col 42 so it sits right of the
-- sidebar over the main editor area.
---@param buf number
---@return number win
local function open_float(buf)
	local cols, lines = vim.o.columns, vim.o.lines
	local width = math.max(60, math.floor(cols * 0.65))
	local height = math.max(15, math.floor(lines * 0.7))
	local col = math.min(cols - width - 2, 42)
	local row = math.floor((lines - height) / 2)
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
		title = " Preview ",
		title_pos = "center",
		focusable = true,
		zindex = 50,
		noautocmd = true,
	})
	vim.wo[win].number = true
	vim.wo[win].relativenumber = false
	vim.wo[win].cursorline = true
	vim.wo[win].signcolumn = "no"
	vim.wo[win].wrap = false
	vim.wo[win].foldenable = false
	return win
end

-- Get the active explorer picker, if any.
---@return snacks.Picker?
local function explorer_picker()
	return Snacks.picker.get({ source = "explorer" })[1]
end

-- Is the explorer the user's current interaction context? Used to gate
-- auto-preview updates: when focus has moved away (another picker, the
-- main editor), explorer's on_change still re-fires in the background
-- (matcher re-runs, picker regaining bookkeeping after another picker
-- closes) and would otherwise shuffle the float behind the user's back.
-- The float window itself counts as focused — the user is still
-- interacting with the explorer subsystem.
---@return boolean
local function explorer_focused()
	local p = explorer_picker()
	if not p then
		return false
	end
	local cur = vim.api.nvim_get_current_win()
	-- Mirror valid_float()'s nvim_win_is_valid pattern. snacks's Win
	-- wrapper (p.list.win / p.input.win) holds the underlying winid in
	-- its `.win` field, which can briefly outlive the window during
	-- teardown — check it's actually live before comparing.
	local function focused_on(w)
		return w and w.win and vim.api.nvim_win_is_valid(w.win) and cur == w.win
	end
	if focused_on(p.list and p.list.win) then
		return true
	end
	if focused_on(p.input and p.input.win) then
		return true
	end
	if valid_float() and cur == Preview.state.win then
		return true
	end
	return false
end

-- picker:current() is typed as snacks.picker.Item? (the base item type),
-- but our actions only run inside the explorer source — at runtime it's
-- always an explorer item or nil. This wraps the type narrowing so call
-- sites stay free of inline `--[[@as ...]]` clutter.
---@param picker snacks.Picker
---@return snacks.picker.explorer.Item?
local function current_explorer_item(picker)
	return picker:current() --[[@as snacks.picker.explorer.Item?]]
end

-- Hand focus back to the explorer list (used by `q` in float). The
-- regular list ↔ float cycle uses vim-native <C-w>p; this helper exists
-- for `q` which has different semantics (close float, then focus list).
local function focus_list()
	local p = explorer_picker()
	if p and vim.api.nvim_win_is_valid(p.list.win.win) then
		vim.api.nvim_set_current_win(p.list.win.win)
	end
end

-- Commit the preview into the main editor: close the float, :edit the
-- real file in the main window, jump to the float's cursor row. Used
-- by both <CR>-on-list (Preview.confirm) and <CR>-in-float
-- (bind_float_keys).
--
-- The picker is intentionally kept open. snacks's explorer source
-- defaults to `auto_close = false` and `jump = { close = false }`
-- (sources.lua:63-64); the sidebar is meant to persist across file opens.
local function commit_from_preview()
	if not valid_float() then
		return
	end
	---@diagnostic disable-next-line: need-check-nil  -- valid_float() guards this
	local pos = vim.api.nvim_win_get_cursor(Preview.state.win)
	local file = Preview.state.file
	-- Mark this file for one-shot on_change suppression so the trailing
	-- throttle re-fire doesn't re-open the float ~60ms later. See
	-- module-state docs above for the throttle mechanics.
	Preview.skip_file = file
	close_float()
	local picker = explorer_picker()
	if picker and vim.api.nvim_win_is_valid(picker.main) then
		vim.api.nvim_set_current_win(picker.main)
	end
	vim.cmd.edit(vim.fn.fnameescape(file))
	pcall(vim.api.nvim_win_set_cursor, 0, pos)
	vim.cmd("normal! zz")
end

-- Float-side keymaps. The float buffer is a scratch with bufhidden =
-- "wipe", so these buffer-local maps die with it — no cleanup needed.
--
-- We deliberately do NOT bind the cycle-back key here. Vim's native
-- <C-w>p (previous window) does the right thing from the float — its
-- "previous" is the list, since that's where focus came from. Adding a
-- buffer-local override would just duplicate vim's semantics.
---@param buf number
local function bind_float_keys(buf)
	local map = function(lhs, rhs, desc)
		vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, silent = true, desc = desc })
	end
	map("q", function()
		close_float()
		focus_list()
	end, "Preview: close float")
	map("<CR>", commit_from_preview, "Preview: open at this line")
end

-- Update the float to reflect the given item, or close it if the item
-- isn't previewable (directory, binary, oversized, unreadable).
---@param item snacks.picker.explorer.Item?
function Preview.update(item)
	if not item or item.dir or not item.file then
		close_float()
		return
	end
	local buf = load_scratch(item.file)
	if not buf then
		close_float()
		return
	end
	if not valid_float() then
		Preview.state = { win = open_float(buf), buf = buf, file = item.file }
	else
		-- Same float window, swap buffers. Old scratch self-wipes via
		-- bufhidden="wipe" once the window stops showing it.
		---@diagnostic disable-next-line: need-check-nil  -- valid_float() guards this
		vim.api.nvim_win_set_buf(Preview.state.win, buf)
		Preview.state.buf = buf
		Preview.state.file = item.file
	end
	bind_float_keys(buf)
end

-- ---- snacks lifecycle hooks ----

---@param _ snacks.Picker
---@param item snacks.picker.explorer.Item?
function Preview.on_change(_, item)
	-- One-shot skip: absorb the trailing throttle re-fire that snacks
	-- emits ~60ms after a confirm. Always clear (even when no item) so
	-- the marker never persists past one event.
	local skip = Preview.skip_file
	Preview.skip_file = nil
	if not item then
		return
	end
	if skip and item.file == skip then
		return
	end
	-- Focus gate: skip when explorer isn't the current interaction
	-- context. Background re-fires (matcher re-runs after another picker
	-- closes, etc.) shouldn't pop or update the preview.
	if not explorer_focused() then
		return
	end
	if Preview.auto then
		Preview.update(item)
	end
end

function Preview.on_close()
	close_float()
end

-- ---- snacks actions ----

-- <A-p>: toggle the preview popup. Same key on the trouble side
-- (plugins/ui/trouble.lua) — symmetric across both sidebar tools.
---@param picker snacks.Picker
function Preview.toggle(picker)
	if valid_float() then
		close_float()
	else
		Preview.update(current_explorer_item(picker))
	end
end

-- P: trouble's `P` semantics — toggle auto-preview mode. When turning
-- auto back on, refresh immediately so the user sees the current item.
---@param picker snacks.Picker
function Preview.toggle_auto(picker)
	Preview.auto = not Preview.auto
	vim.notify("Explorer auto-preview: " .. (Preview.auto and "ON" or "OFF"), vim.log.levels.INFO)
	if Preview.auto then
		Preview.update(current_explorer_item(picker))
	end
end

-- <C-w>p in list: focus the float (cycle into preview). The reverse leg
-- (preview → list) uses vim-native <C-w>p from the float — see
-- bind_float_keys above. Same key in both directions = one cycle.
--
-- snacks-only — no equivalent on the trouble side. trouble's preview
-- is ephemeral by design (auto-closes on list WinLeave); fighting that
-- to enable focus-into-preview needs an autocmd-suppression hack plus
-- ideally a force-scratch monkey-patch to keep it read-only when
-- focused, which proved too invasive. trouble keeps its native flow.
--
-- We're shadowing vim's built-in <C-w>p inside the explorer list buffer
-- only; outside this buffer, <C-w>p still does the native "previous
-- window" thing. The fallback below — `wincmd p` when no float exists —
-- defers to that native semantic so the shadow doesn't cost the user
-- anything in that state.
---@param _picker snacks.Picker
function Preview.focus(_picker)
	if valid_float() then
		---@diagnostic disable-next-line: need-check-nil  -- valid_float() guards this
		vim.api.nvim_set_current_win(Preview.state.win)
	else
		vim.cmd("wincmd p")
	end
end

-- <C-f> / <C-b>: scroll the float. snacks's defaults bind these to
-- preview_scroll_down/up which target picker.preview.win — invalid for
-- us since we keep `preview = false` on the explorer source.
---@param direction "down"|"up"
local function scroll(direction)
	return function()
		if not valid_float() then
			return
		end
		local key = direction == "down" and "<C-d>" or "<C-u>"
		local termcode = vim.api.nvim_replace_termcodes(key, true, false, true)
		---@diagnostic disable-next-line: need-check-nil  -- valid_float() guards this
		vim.api.nvim_win_call(Preview.state.win, function()
			vim.cmd("normal! " .. termcode)
		end)
	end
end
Preview.scroll_down = scroll("down")
Preview.scroll_up = scroll("up")

-- <CR> / l in list: preview-aware confirm.
--   * Directory / no float / float showing different file: delegate to
--     snacks's default `confirm` (handles dir-toggle and standard
--     file-open at line 1).
--   * File matches active float: commit_from_preview() — close float,
--     edit file, restore cursor to the float's position.
---@param picker snacks.Picker
---@param item snacks.picker.explorer.Item?
function Preview.confirm(picker, item)
	if not item or item.dir or not valid_float() or Preview.state.file ~= item.file then
		picker:action("confirm")
		return
	end
	commit_from_preview()
end

-- ============================================================
-- Plugin spec
-- ============================================================

return {
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		opts = {
			-- Friendly help popup: rounded centered float with a title,
			-- instead of the default dense grid docked at the bottom.
			styles = {
				help = {
					position = "float",
					backdrop = false,
					border = "rounded",
					title = " Keymaps — press ? to close ",
					title_pos = "center",
					row = 0.15,
					col = 0.5,
					width = 0.6,
				},
			},
			picker = {
				enabled = true,
				-- Replace vim.ui.select with Snacks' picker system-wide.
				-- Auto-benefits any plugin that prompts via vim.ui.select
				-- (e.g. LintaoAmons/bookmarks.nvim's list/delete prompts).
				ui_select = true,
				layout = { preset = "default" },
				-- Wider columns → fewer keys per row, each entry gets breathing room.
				actions = {
					toggle_help_input = function(p)
						p.input.win:toggle_help({ col_width = 45, key_width = 14 })
					end,
					toggle_help_list = function(p)
						p.list.win:toggle_help({ col_width = 45, key_width = 14 })
					end,
				},
				sources = {
					explorer = {
						-- Floating preview lifecycle (Preview module above).
						-- on_show is intentionally omitted: state is already nil after
						-- the last on_close, and Preview.auto is meant to persist across
						-- explorer sessions.
						on_change = Preview.on_change,
						on_close = Preview.on_close,
						-- z[oc] single dir · z[OC] recursive · z[RM] whole tree · z[aA] toggle.
						actions = {
							fold_open = fold_action(function(_, path)
								require("snacks.explorer.tree"):open(path)
							end),
							fold_open_recursive = fold_action(function(node)
								open_recursive(node)
							end),
							fold_close_recursive = fold_action(function(node)
								close_recursive(node)
							end),
							fold_toggle = fold_action(function(_, path)
								require("snacks.explorer.tree"):toggle(path)
							end),
							fold_toggle_recursive = fold_action(function(node)
								if node.open then
									close_recursive(node)
								else
									open_recursive(node)
								end
							end),
							-- Special-cased: operates on the cwd root, not the cursor's
							-- fold target — doesn't fit the fold_action factory.
							fold_open_all = function(picker)
								local Tree = require("snacks.explorer.tree")
								open_recursive(Tree:find(picker:cwd()))
								fold_refresh(picker)
							end,
							preview_toggle = Preview.toggle,
							preview_toggle_auto = Preview.toggle_auto,
							preview_focus = Preview.focus,
							preview_scroll_down = Preview.scroll_down,
							preview_scroll_up = Preview.scroll_up,
							preview_confirm = Preview.confirm,
						},
						win = {
							list = {
								keys = {
									["]c"] = "explorer_git_next",
									["[c"] = "explorer_git_prev",
									["zo"] = "fold_open",
									["zc"] = "explorer_close",
									["zO"] = "fold_open_recursive",
									["zC"] = "fold_close_recursive",
									["za"] = "fold_toggle",
									["zA"] = "fold_toggle_recursive",
									["zR"] = "fold_open_all",
									["zM"] = "explorer_close_all",
									-- Floating preview popup. p stays as explorer_paste —
									-- file-manager paste convention wins.
									["<A-p>"] = "preview_toggle", -- toggle popup; same key on trouble side.
									["P"] = "preview_toggle_auto", -- toggle auto-preview (trouble's `P` semantics).
									["<C-f>"] = "preview_scroll_down", -- override snacks default.
									["<C-b>"] = "preview_scroll_up",
									["<C-w>p"] = "preview_focus", -- cycle into preview; reverse uses vim-native <C-w>p from float.
									["<CR>"] = "preview_confirm", -- open at preview position.
									["l"] = "preview_confirm",
								},
							},
						},
					},
				},
			},
			explorer = {
				enabled = true,
				replace_netrw = true, -- hijack directory opens (was Neo-tree hijack_netrw)
			},
			dashboard = { enabled = true }, -- 启动页
			notifier = { enabled = true },
		},
		keys = {
			{
				"<leader>vp",
				function()
					Snacks.explorer()
				end,
				desc = "Explorer",
			},
			{
				"<leader>,",
				function()
					Snacks.picker.buffers()
				end,
				desc = "Buffers",
			},
			{
				"<leader>/",
				function()
					Snacks.picker.grep()
				end,
				desc = "Grep",
			},
			{
				"<leader>ss",
				function()
					Snacks.picker.lsp_workspace_symbols()
				end,
				desc = "Workspace Symbols",
			},
			{
				"<leader>sc",
				function()
					Snacks.picker.commands()
				end,
				desc = "Commands",
			},
			{
				"<leader>sk",
				function()
					Snacks.picker.keymaps()
				end,
				desc = "Keymaps",
			},
			-- Buffer 内 fuzzy 搜索 —— `/` 的 picker 形态：先模糊找行，
			-- 预览框在主窗口实时定位，回车跳转。和 `/` 互补：
			--   /            精确正则 + n/N 串联 + hlslens 计数（结构化导航）
			--   <leader>sb   模糊匹配 + 预览 + 一次性跳转（"我大概记得几个词"）
			{
				"<leader>sb",
				function()
					Snacks.picker.lines()
				end,
				desc = "Buffer Lines (fuzzy /)",
			},
			-- 跨已打开 buffer 的 live ripgrep —— 对 <leader>/ 的项目级 grep
			-- 是补集：只想在当前打开的几个文件里找时用这个，避免被全项目噪音淹。
			{
				"<leader>sB",
				function()
					Snacks.picker.grep_buffers()
				end,
				desc = "Grep Open Buffers",
			},
			-- 光标下词 / visual 选区直接喂给 ripgrep，无输入步骤。
			{
				"<leader>sw",
				function()
					Snacks.picker.grep_word()
				end,
				mode = { "n", "x" },
				desc = "Grep Word/Selection",
			},
			-- 历史搜索条目 picker —— 翻 `/` 历史时比 q/ 命令窗更直观。
			{
				"<leader>s/",
				function()
					Snacks.picker.search_history()
				end,
				desc = "Search History",
			},
			{
				"<leader>vn",
				function()
					Snacks.notifier.show_history()
				end,
				desc = "Notification History",
			},
			{
				"<localleader>G",
				function()
					Snacks.lazygit()
				end,
				desc = "Git: Lazygit",
			},
			{
				"<localleader>gl",
				function()
					Snacks.lazygit.log()
				end,
				desc = "Git: Log (Lazygit)",
			},
		},
	},
}
