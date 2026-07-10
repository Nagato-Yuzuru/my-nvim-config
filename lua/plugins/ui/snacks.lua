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
local function fold_refresh(picker) require("snacks.explorer.actions").update(picker, { refresh = true }) end

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
-- snacks's layout system is single-rooted, so the built-in `preview`
-- window can only live inside the picker container or hijack the main
-- editor (`preview = "main"`). We instead drive a real
-- `relative = "editor"` float decoupled from the picker layout —
-- equivalent to trouble's `preview = { type = "float" }`.
--
-- The float state machine / scratch-load pipeline / stale-race guard live
-- in tools/float_preview.lua (shared with lua/plugins/ui/neominimap.lua).
-- This file supplies only the host-specific pieces: editor-centered
-- geometry, the explorer focus gate, and the commit-into-editor semantics.
--
-- Toggle keys aligned with trouble.nvim and the neominimap preview popup:
--   <A-p>  toggle preview window (one-shot show / hide)
--   P      toggle auto-preview mode (on_change-driven follow vs frozen)
-- p stays bound to explorer_paste — file-manager paste convention wins.
--
-- Default: auto-preview OFF, no float on explorer entry. Press <A-p> to
-- snapshot the current item; press P to enable cursor-tracking. Rationale:
-- ambient auto-open caused spurious pops whenever on_change re-fired in
-- the background (matcher re-runs, focus returning from another picker).
-- Making the open explicit kills that whole class of surprises.

local float_preview = require("tools.float_preview")

-- Editor-centered geometry. Sidebar is 40 cols wide on the left; place
-- the float starting at col 42 so it sits right of the sidebar over the
-- main editor area. Percentages hardcoded for v1; never returns nil (the
-- math.max floors keep it valid at any terminal size).
---@return vim.api.keyset.win_config
local function editor_geometry()
	local cols, lines = vim.o.columns, vim.o.lines
	local width = math.max(60, math.floor(cols * 0.65))
	local height = math.max(15, math.floor(lines * 0.7))
	local col = math.min(cols - width - 2, 42)
	local row = math.floor((lines - height) / 2)
	return {
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
	}
end

-- Get the active explorer picker, if any.
---@return snacks.Picker?
local function explorer_picker() return Snacks.picker.get({ source = "explorer" })[1] end

-- Forward-declared so the float-key / commit closures below can reference
-- it before M.new (which needs those closures for on_show) runs.
---@type FloatPreview
local preview

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
-- real file in the main window, jump to the float's cursor row. Used by
-- both <CR>-on-list (Preview.confirm) and <CR>-in-float (bind_float_keys).
--
-- The picker is intentionally kept open. snacks's explorer source defaults
-- to `auto_close = false` and `jump = { close = false }`; the sidebar is
-- meant to persist across file opens.
--
-- preview:mute(file) absorbs snacks's trailing-edge throttle re-fire
-- (snacks/util/init.lua — _show_preview is wrapped in a 60ms throttle that
-- fires once more after the timer expires if a call was queued during the
-- window). Without it, pressing `l` to open a file made the float pop back
-- up ~60ms later. The next show_auto(file) is swallowed exactly once.
local function commit_from_preview()
	local win = preview:win()
	if not win then
		return
	end
	local pos = vim.api.nvim_win_get_cursor(win)
	local file = preview:key()
	preview:mute(file)
	preview:close()
	local picker = explorer_picker()
	if picker and vim.api.nvim_win_is_valid(picker.main) then
		vim.api.nvim_set_current_win(picker.main)
	end
	vim.cmd.edit(vim.fn.fnameescape(file))
	pcall(vim.api.nvim_win_set_cursor, 0, pos)
	vim.cmd("normal! zz")
end

-- Float-side keymaps, (re)bound by on_show after every (re)build. The
-- float buffer is a scratch with bufhidden = "wipe", so these buffer-local
-- maps die with it — no cleanup needed.
--
-- We deliberately do NOT bind the cycle-back key here. Vim's native <C-w>p
-- (previous window) does the right thing from the float — its "previous"
-- is the list, since that's where focus came from.
---@param buf number
local function bind_float_keys(buf)
	local map = function(lhs, rhs, desc)
		vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, silent = true, desc = desc })
	end
	map("q", function()
		preview:close()
		focus_list()
	end, "Preview: close float")
	map("<CR>", commit_from_preview, "Preview: open at this line")
end

-- Default source (file path → read-only scratch) is exactly what the
-- explorer wants, so `source` is omitted. Geometry is host-supplied; keys
-- are (re)bound on every build via on_show.
preview = float_preview.new({
	geometry = editor_geometry,
	wo = {
		number = true,
		relativenumber = false,
		cursorline = true,
		signcolumn = "no",
		wrap = false,
		foldenable = false,
	},
	on_show = function(buf) bind_float_keys(buf) end,
})

-- Is the explorer the user's current interaction context? Gates
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
	-- snacks's Win wrapper (p.list.win / p.input.win) holds the underlying
	-- winid in its `.win` field, which can briefly outlive the window
	-- during teardown — check it's actually live before comparing.
	local function focused_on(w) return w and w.win and vim.api.nvim_win_is_valid(w.win) and cur == w.win end
	if focused_on(p.list and p.list.win) then
		return true
	end
	if focused_on(p.input and p.input.win) then
		return true
	end
	if cur == preview:win() then
		return true
	end
	return false
end

-- picker:current() is typed as snacks.picker.Item? (the base item type),
-- but our actions only run inside the explorer source — at runtime it's
-- always an explorer item or nil. Narrow to the previewable file path
-- (nil for directories / no selection), the req shape the default source
-- (and mute) key off.
---@param picker snacks.Picker
---@return string?
local function current_file(picker)
	local item = picker:current() --[[@as snacks.picker.explorer.Item?]]
	return item and not item.dir and item.file or nil
end

-- Action namespace referenced by the plugin spec below.
local Preview = {}

-- ---- snacks lifecycle hooks ----

---@param _ snacks.Picker
---@param item snacks.picker.explorer.Item?
function Preview.on_change(_, item)
	-- No selection: leave the float as-is (don't close it).
	if not item then
		return
	end
	-- Focus gate stays host-side: background re-fires (matcher re-runs
	-- after another picker closes, etc.) shouldn't pop or move the float.
	-- The one-shot mute (armed by commit) is consumed inside show_auto.
	if not explorer_focused() then
		return
	end
	preview:show_auto(not item.dir and item.file or nil)
end

function Preview.on_close() preview:close() end

-- ---- snacks actions ----

-- <A-p>: toggle the preview popup. Same key on the trouble side
-- (plugins/ui/trouble.lua) — symmetric across both sidebar tools.
---@param picker snacks.Picker
function Preview.toggle(picker) preview:toggle(current_file(picker)) end

-- P: trouble's `P` semantics — toggle auto-preview mode. The host owns the
-- notify (message is explorer-specific); the module owns the flip +
-- immediate refresh-on-enable.
---@param picker snacks.Picker
function Preview.toggle_auto(picker)
	local on = preview:toggle_auto(current_file(picker))
	vim.notify("Explorer auto-preview: " .. (on and "ON" or "OFF"), vim.log.levels.INFO)
end

-- <C-w>p in list: focus the float (cycle into preview). The reverse leg
-- (preview → list) uses vim-native <C-w>p from the float — see
-- bind_float_keys above. Same key in both directions = one cycle.
--
-- We shadow vim's built-in <C-w>p inside the explorer list buffer only;
-- the `wincmd p` fallback (no float) defers to the native "previous
-- window" semantic so the shadow costs nothing in that state.
function Preview.focus()
	local win = preview:win()
	if win then
		vim.api.nvim_set_current_win(win)
	else
		vim.cmd("wincmd p")
	end
end

-- <C-f> / <C-b>: scroll the float. snacks's defaults bind these to
-- preview_scroll_down/up which target picker.preview.win — invalid for us
-- since we keep `preview = false` on the explorer source.
function Preview.scroll_down() preview:scroll("down") end
function Preview.scroll_up() preview:scroll("up") end

-- <CR> / l in list: preview-aware confirm.
--   * Directory / no float / float showing different file: delegate to
--     snacks's default `confirm` (dir-toggle + standard file-open).
--   * File matches active float: commit_from_preview() — close float, edit
--     file, restore cursor to the float's position.
---@param picker snacks.Picker
---@param item snacks.picker.explorer.Item?
function Preview.confirm(picker, item)
	if not item or item.dir or preview:key() ~= item.file then
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
		-- :ImageTrust — 远程图片放行的审计/撤销面(授予键位在下方 keys 的
		-- ,ia*;机制与持久库在 lua/tools/image_render.lua)。挂 init:命令
		-- 注册不该等首次按键,module 本身仍按需 require。
		init = function()
			vim.api.nvim_create_user_command("ImageTrust", function(cmd)
				local ir = require("tools.image_render")
				if cmd.args == "clear" then
					ir.trust_clear()
					ir.refresh_docs()
					vim.notify("Image trust: 已清空(含持久库)")
				else
					vim.notify(table.concat(ir.trust_list(), "\n"))
				end
			end, {
				nargs = "?",
				complete = function() return { "list", "clear" } end,
				desc = "List/clear remote-image trust grants",
			})
		end,
		-- 预加载 notifier,绕过 snacks 装的 vim.notify 懒加载 shim
		-- (snacks/init.lua:220-223)。该 shim 在第一次 vim.notify 调用时
		-- 才 require('snacks.notifier');如果加载链里再触发一次 vim.notify
		-- (例如某第三方插件命中 vim.deprecate),会递归 require 同一模块,
		-- Lua 报 "loop or previous error loading module 'snacks.notifier'"。
		-- 触发场景:<leader>tT → neotest → rustaceanvim 调 deprecated 的
		-- client.request → vim.deprecate → vim.notify shim → 套娃。
		config = function(_, opts)
			require("snacks").setup(opts)
			if opts.notifier and opts.notifier.enabled then
				vim.notify = require("snacks.notifier").notify
			end
		end,
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
					toggle_help_input = function(p) p.input.win:toggle_help({ col_width = 45, key_width = 14 }) end,
					toggle_help_list = function(p) p.list.win:toggle_help({ col_width = 45, key_width = 14 }) end,
				},
				sources = {
					explorer = {
						-- Floating preview lifecycle (Preview actions above). The
						-- snacks-picker on_show hook is intentionally omitted: the
						-- module-level `preview` controller persists across explorer
						-- sessions (its auto-follow flag survives on_close, which only
						-- tears the float down).
						on_change = Preview.on_change,
						on_close = Preview.on_close,
						-- z[oc] single dir · z[OC] recursive · z[RM] whole tree · z[aA] toggle.
						actions = {
							fold_open = fold_action(function(_, path) require("snacks.explorer.tree"):open(path) end),
							fold_open_recursive = fold_action(function(node) open_recursive(node) end),
							fold_close_recursive = fold_action(function(node) close_recursive(node) end),
							fold_toggle = fold_action(
								function(_, path) require("snacks.explorer.tree"):toggle(path) end
							),
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
			-- 终端内嵌图片渲染:markdown 内联图 + LaTeX 数学 + mermaid + PDF
			-- + 打开图片文件预览。取代旧的 image.nvim markdown 集成
			-- (image.nvim 现仅留给 leetcode,见 lua/plugins/ui/image.lua)。
			--
			-- 为什么换:snacks 判转换失败只看进程退出码、不看 stderr
			-- (snacks/util/spawn.lua:231),所以 SVG 缺字体只是 stderr 告警、
			-- 退出码仍 0 → 照常出图,不像 image.nvim 的 magick_cli 会报错。
			-- vector(svg/pdf)默认 -density 192 更清晰,转换结果落磁盘缓存
			-- (~/.cache/snacks/image)二次打开秒开。
			--
			-- Ghostty + tmux:snacks 在 TMUX 内用
			-- `tmux display-message -p '#{client_termname}'` 认出外层 Ghostty
			-- 并自动 set allow-passthrough(snacks/image/terminal.lua);
			-- Ghostty 走 unicode placeholder,tmux 下内联渲染 OK。
			-- 万一没出图,临时 `SNACKS_GHOSTTY=1` 强制探测。
			--
			-- 依赖:仅 imagemagick(brew 标准 formula,已 link 进 PATH;PDF
			-- delegate 走系统 ghostscript)。数学/mermaid 刻意**不**在终端渲染
			-- —— 那需要 tectonic/TeX + mmdc(=puppeteer+headless Chromium)两条
			-- 重依赖链,而这两类内容本就是浏览器原生技术。图形化预览走
			-- live-preview.nvim(,mb;lua/plugins/lang/markdown.lua),浏览器端
			-- mermaid-js/KaTeX 渲染,零二进制。math.enabled=false 连"缺
			-- tectonic"的警告也不出;mermaid 无独立开关,snacks 对缺 mmdc 的
			-- 处理是警告一次 + 跳过该类型,不影响普通图片。
			image = {
				enabled = true,
				-- 远程图片默认不自动联网:任何 scheme:// 的图片 src,snacks 会用
				-- curl -L 自动拉取(inline + ,iv hover 同一条链、跟随重定向、不校验
				-- content-type)=「打开文档就向任意主机发请求」。官方 resolve 钩子
				-- 把远程 src 换成本地占位图断掉它;放行走 ,ia* 三档信任(图/文件/
				-- 仓库,命中才交回 snacks 抓)。策略/占位图/持久库全在
				-- tools.image_render(含 SSRF/tracking-pixel 说明)。file:// 本地读放行。
				resolve = function(file, src) return require("tools.image_render").block_remote(file, src) end,
				math = { enabled = false }, -- 数学位图渲染永久关闭,见上
				doc = {
					enabled = true,
					inline = true, -- Ghostty/Kitty 支持 placeholder → 内联进 buffer
					-- 尺寸:格数上限,同时作用于内联渲染和 <localleader>i 浮窗
					-- (浮窗贴合图片渲染尺寸、不会超过它)。调大=更大,调小=更小。
					-- 无法逐图设尺寸——snacks 不解析 markdown 的 {width=}。
					max_width = 80,
					max_height = 40,
				},
			},
		},
		keys = {
			{
				"<leader>vp",
				function() Snacks.explorer() end,
				desc = "Explorer",
			},
			{
				"<leader>,",
				function() Snacks.picker.buffers() end,
				desc = "Buffers",
			},
			{
				"<leader>/",
				function()
					-- -P 切到 PCRE2 引擎，支持 lookbehind/lookahead 等 Rust regex 不支持的特性
					Snacks.picker.grep({ args = { "-P" } })
				end,
				desc = "Grep",
			},
			{
				"<leader>ss",
				function() Snacks.picker.lsp_workspace_symbols() end,
				desc = "Workspace Symbols",
			},
			{
				"<leader>sc",
				function() Snacks.picker.commands() end,
				desc = "Commands",
			},
			{
				"<leader>sk",
				function() Snacks.picker.keymaps() end,
				desc = "Keymaps",
			},
			-- Buffer 内 fuzzy 搜索 —— `/` 的 picker 形态：先模糊找行，
			-- 预览框在主窗口实时定位，回车跳转。和 `/` 互补：
			--   /            精确正则 + n/N 串联 + hlslens 计数（结构化导航）
			--   <leader>sb   模糊匹配 + 预览 + 一次性跳转（"我大概记得几个词"）
			{
				"<leader>sb",
				function() Snacks.picker.lines() end,
				desc = "Buffer Lines (fuzzy /)",
			},
			-- 跨已打开 buffer 的 live ripgrep —— 对 <leader>/ 的项目级 grep
			-- 是补集：只想在当前打开的几个文件里找时用这个，避免被全项目噪音淹。
			{
				"<leader>sB",
				function() Snacks.picker.grep_buffers() end,
				desc = "Grep Open Buffers",
			},
			-- 光标下词 / visual 选区直接喂给 ripgrep，无输入步骤。
			{
				"<leader>sw",
				function() Snacks.picker.grep_word() end,
				mode = { "n", "x" },
				desc = "Grep Word/Selection",
			},
			-- 历史搜索条目 picker —— 翻 `/` 历史时比 q/ 命令窗更直观。
			{
				"<leader>s/",
				function() Snacks.picker.search_history() end,
				desc = "Search History",
			},
			{
				"<leader>vn",
				function() Snacks.notifier.show_history() end,
				desc = "Notification History",
			},
			{
				-- 对齐 ideavimrc：<localleader>G = Vcs.QuickListPopupAction
				"<localleader>G",
				function() Snacks.lazygit() end,
				desc = "Git: Lazygit",
			},
			{
				"<localleader>gl",
				function() Snacks.lazygit.log() end,
				desc = "Git: Log (Lazygit)",
			},
			-- <localleader>i* 图片命名空间(ft 限定文档类型)。snacks.image 不带
			-- 默认键,这里手绑(开关/重挂的实现在 lua/tools/image_render.lua,
			-- 对 snacks 内部命名的依赖集中在那里):
			--   ,iv 光标处图片放大到浮窗看(inline 已渲染时给更大的浮窗)
			--   ,ii 图片渲染 on/off(仅当前 buffer;,mr/,mR 会把它拉回和文字
			--       渲染一致的状态)
			--   ,it 切换 inline 内联 ↔ float 浮窗模式,当前 buffer 立即重渲
			--   ,ia* 放行(信任)子命名空间——被拦的远程图按尺度放行:
			--       ,iai 光标处这张图(session) ,iaf 本文件(session)
			--       ,iar 本仓库(持久落 state;非 git 目录拒绝)
			--       审计/撤销 :ImageTrust [list|clear](上方 init 注册)
			{
				"<localleader>iv",
				function() Snacks.image.hover() end,
				ft = { "markdown", "markdown.mdx", "tex", "typst", "norg" },
				desc = "Image: view at cursor (float)",
			},
			{
				"<localleader>ii",
				function()
					local on = require("tools.image_render").buf_set(nil, nil)
					vim.notify("snacks.image render: " .. (on and "on" or "off"))
				end,
				ft = { "markdown", "markdown.mdx", "tex", "typst", "norg" },
				desc = "Image: toggle rendering (buffer)",
			},
			{
				"<localleader>it",
				function()
					local doc = Snacks.image.config.doc
					doc.inline = not doc.inline
					require("tools.image_render").buf_refresh()
					vim.notify("snacks.image inline: " .. tostring(doc.inline))
				end,
				ft = { "markdown", "markdown.mdx", "tex", "typst", "norg" },
				desc = "Image: toggle inline rendering",
			},
			{
				"<localleader>iai",
				function() require("tools.image_render").trust_image_at_cursor() end,
				ft = { "markdown", "markdown.mdx", "tex", "typst", "norg" },
				desc = "Image: allow image at cursor (session)",
			},
			{
				"<localleader>iaf",
				function()
					local ir = require("tools.image_render")
					local key = ir.trust_file(vim.api.nvim_buf_get_name(0))
					if key then
						ir.refresh_docs()
						vim.notify("Image trust: 本文件已放行(session) " .. key)
					else
						vim.notify("Image trust: buffer 没有文件名", vim.log.levels.WARN)
					end
				end,
				ft = { "markdown", "markdown.mdx", "tex", "typst", "norg" },
				desc = "Image: allow this file (session)",
			},
			{
				"<localleader>iar",
				function()
					local ir = require("tools.image_render")
					local root = ir.trust_repo(vim.api.nvim_buf_get_name(0))
					if root then
						ir.refresh_docs()
						vim.notify("Image trust: 仓库已持久放行 " .. root)
					else
						vim.notify("Image trust: 不在 git 仓库内,用 ,iaf/,iai", vim.log.levels.WARN)
					end
				end,
				ft = { "markdown", "markdown.mdx", "tex", "typst", "norg" },
				desc = "Image: allow this repo (persistent)",
			},
		},
	},
}
