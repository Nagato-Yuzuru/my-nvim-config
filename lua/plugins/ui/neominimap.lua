-- neominimap.nvim — JetBrains CodeGlance 的对位插件。
--
-- 为什么选它（不是 mini.map）：CodeGlance 的核心视觉是"带语法着色的代码缩略图"，
-- mini.map 是单色 braille 编码的"轨道 + 标记条"，看不出代码形状。neominimap 用
-- treesitter 高亮 + braille 渲染，最贴近 JetBrains/VSCode minimap 的观感。
--
-- IdeaVim 那边没有对位绑定：CodeGlance 是 JetBrains 插件，UI 在 gutter 区域，
-- 不通过 IdeaVim mapping，由 IDE 直接渲染。这是 CLAUDE.md 允许的"genuinely
-- nvim-only"非对称项（同 codelens / Flash Treesitter）。
--
-- 与 edgy.nvim 共存：neominimap 默认走浮动窗口（layout = "float"），不进 dock，
-- 不会和 edgy 抢 right edge（Aerial 已占）。如果改成 split layout，需要回过头
-- 把 ft = "neominimap" 加进 plugins/ui/edgy.lua 的 right spec。
--
-- 触发策略：lazy 加载到 VeryLazy，启动后默认全局 enable。性能不敏感的 buffer
-- 才会有 minimap（filetypes 黑名单见下），大文件打开时 neominimap 自己有 line
-- 数与文件大小阈值兜底（buf_filter）。
--
-- Focus（光标进出 minimap 浮窗）：<C-x>m 调 :Neominimap ToggleFocus。
-- 走 <C-x>* 命名空间（窗口/buffer 操作族）；进 minimap 后 j/k 滚动、<CR> 跳到
-- 主窗对应行。float layout 下没有 <C-w>l 进入路径，所以这个键必要。
--
-- Preview vs commit（**故意切开**，CodeGlance 风格）：
-- neominimap 默认 sync_cursor=true，意味着 minimap 内每次 CursorMoved 都会立刻
-- 把主窗光标拽过去——"看一下"和"跳过去"是同一动作，没法预览。这里改成
-- sync_cursor=false 并叠一层"弹出浮窗预览"，对齐 JetBrains CodeGlance 的悬浮气泡：
--   * 主窗光标移动 → minimap viewport 指示带 **仍会跟随**（这条同步走另一个分支，
--     不受 sync_cursor 控制，见 window/float/autocmds.lua:118-124）。
--   * minimap 内 j/k 移动 → 主窗 **不动**；同时在 minimap 左侧弹出一个浮窗
--     预览源文件该行附近的可读代码（直接挂源 buffer，不复制——保留 treesitter
--     高亮、folds 等所有原 buffer 的渲染状态）。
--   * <CR>     在 minimap buffer 里：commit 跳转 → 把主窗光标移到当前 minimap
--             光标对应的源行，预览浮窗关闭，自动 unfocus 回主窗。
--   * q/<Esc> 在 minimap buffer 里：cancel → 直接 unfocus 回主窗，预览浮窗关闭，
--             主窗光标不动。
-- 这套绑定在下方 config() 里通过 FileType=neominimap 的 autocmd 注册（buffer-local，
-- 不污染全局 <CR>/q/<Esc>）。预览浮窗的开/关也走同一个 FileType callback，
-- 自动绑 CursorMoved/WinLeave 事件。
return {
	"Isrothy/neominimap.nvim",
	version = "v3.*.*",
	event = "VeryLazy",
	keys = {
		-- <leader>vM (uppercase M = Minimap)：与 <leader>vm（bookmarks alias）
		-- 区分。Views 命名空间的 toggle 语义（同 vs/vp/vr/vd 的"toggle 一个面板"）。
		{ "<leader>vM", "<cmd>Neominimap Toggle<cr>", desc = "Toggle minimap" },
		-- <C-x>m: focus 切换。在 <C-x>* 命名空间（窗口/buffer 操作族）里——和
		-- <C-x>2/3 (split)、<C-x>t (new buf)、<C-x>R (rename tab) 同族，意为
		-- "把光标搬进/搬出 minimap 这个特殊窗口"。Minimap 关闭时这个键 no-op。
		{ "<C-x>m", "<cmd>Neominimap ToggleFocus<cr>", desc = "Toggle minimap focus" },
	},
	init = function()
		-- v3 改用 vim.g.neominimap 配置（不再用 setup()），因为它要在 plugin
		-- 启动前就读到 enable 标志。
		vim.g.neominimap = {
			-- 默认开（CodeGlance 风格——常驻显示）。需要临时关掉用 <leader>vM。
			auto_enable = true,

			-- float 比 split 更接近 CodeGlance 的视觉位置（贴右边浮起来，不占
			-- buffer 列宽）；split 会把窗口排版改了，影响主区域。
			layout = "float",

			-- 关掉 minimap → 主窗的实时光标同步——把"预览"和"跳转"拆开。
			-- 主窗 → minimap 方向不受这个 flag 控制，viewport 指示带仍会跟随。
			-- commit 跳转 / cancel 退出 走 buffer-local <CR> / q / <Esc>，注册
			-- 在下方 config() 的 FileType=neominimap autocmd 里。
			sync_cursor = false,

			float = {
				minimap_width = 12,
				margin = { right = 0, top = 0, bottom = 0 },
				z_index = 10,
				window_border = "single",
			},

			-- 渲染：保留 treesitter 着色（着色就是选 neominimap 的全部理由），
			-- diagnostic / git / search 标记都开。
			treesitter = { enabled = true },
			diagnostic = {
				enabled = true,
				severity = vim.diagnostic.severity.HINT,
			},
			git = { enabled = true },
			search = { enabled = true },
			mark = { enabled = false }, -- vim mark 用得少，关掉减视觉噪声

			-- 当前 viewport 的高亮条（minimap 上"我现在看哪里"那块）。
			-- 默认透明 + 边框；这里保留默认，不再覆盖。

			-- 黑名单：dock/工具窗 buffer 不需要缩略图（aerial / trouble / dapui /
			-- neo-tree / snacks 各 picker / overseer / toggleterm 等）。
			-- buftype: "nofile" / "terminal" / "prompt" 一律不渲染。
			buf_filter = function(bufnr)
				local buftype = vim.bo[bufnr].buftype
				if buftype ~= "" then
					return false
				end
				-- 大文件兜底：超 1MB 或超 30k 行的不渲染（neominimap 自己也有
				-- 类似阈值，这里再加一道，避免打开 dump/log 类文件卡顿）。
				local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(bufnr))
				if ok and stats and stats.size > 1024 * 1024 then
					return false
				end
				if vim.api.nvim_buf_line_count(bufnr) > 30000 then
					return false
				end
				return true
			end,
			win_filter = function(winid)
				-- 浮窗（snacks picker / which-key / noice 等）不挂 minimap。
				return vim.api.nvim_win_get_config(winid).relative == ""
			end,

			-- 不渲染的 filetype（即使 buf_filter 通过）。
			exclude_filetypes = {
				"help",
				"qf",
				"aerial",
				"trouble",
				"neo-tree",
				"snacks_picker_list",
				"snacks_picker_input",
				"snacks_dashboard",
				"snacks_notif",
				"snacks_terminal",
				"OverseerList",
				"OverseerOutput",
				"dap-repl",
				"dapui_scopes",
				"dapui_breakpoints",
				"dapui_stacks",
				"dapui_watches",
				"dapui_console",
				"toggleterm",
				"lazy",
				"mason",
				"checkhealth",
				"TelescopePrompt",
				"TelescopeResults",
				"NeogitStatus",
				"NeogitCommitMessage",
				"DressingInput",
				"DressingSelect",
				"noice",
				"notify",
				"alpha",
				"starter",
			},
			exclude_buftypes = {
				"nofile",
				"nowrite",
				"quickfix",
				"terminal",
				"prompt",
			},
		}

		-- minimap buffer 内的 commit / cancel 键 + CodeGlance 风预览浮窗。
		-- 注册在 init 里以便在 plugin VeryLazy 加载、auto_enable 创建第一个
		-- minimap buffer 之前就生效。
		--
		-- 实现细节：
		--
		-- 1) commit 跳转要分 layout 调下层 internal——float / split 的
		--    reset_parent_window_cursor_line 签名不同（float 取 mwinid，split
		--    不取参数从 tabpage 推断），neominimap.api 没暴露统一封装，所以这
		--    里下沉一层。如果 plugin 后续加了 api.commit / api.sync_to_main
		--    这种公开接口应该切过去。
		--
		-- 2) 预览浮窗用 minimap row → source row 的坐标转换（map.coord 模块
		--    暴露的 mcodepoint_to_codepoint），定位源 buffer 的对应行，挂在
		--    一个浮窗里、`zz` 居中。**直接复用源 buffer**（不复制 lines 到
		--    scratch buf），治裸 buffer 的优点是 treesitter 高亮 / folds /
		--    diagnostic 标记全自动正确——和你在主窗看到的渲染完全一致；
		--    代价是 BufWinEnter 之类的 autocmd 会触发一遍（用 noautocmd
		--    open_win 规避）。
		--
		-- 3) 预览浮窗位置：anchor=NE, relative=win(mwinid), col=0, row=0
		--    → 浮窗的右上角贴在 minimap 的左上角，于是浮窗整个出现在 minimap
		--    的左侧，顶部对齐。宽度按 (columns - mwidth - 6) 算，留余量给主窗
		--    边距和浮窗自己的圆角 border；太窄就放弃显示。
		--
		-- 4) `p` / `P` 切换（对齐 trouble.nvim 的语义）：
		--      P = 切"自动预览"模式：preview.auto 翻转。auto=true 时光标在
		--          minimap 内移动会自动开/移动浮窗（默认）；auto=false 时浮
		--          窗冻结，CursorMoved 不刷新。
		--      p = 切"当前预览窗"开关：浮窗在就关掉，不在就打开（即使 auto
		--          关着也能手动打开看一眼）。
		--    preview.auto 的初始值 = true，对应 trouble.nvim 的 auto_preview
		--    默认。状态是 closure-local，跨 buffer 共享（一个会话里只一份）。
		local preview = { win = nil, source_buf = nil, auto = true }

		local function close_preview()
			if preview.win and vim.api.nvim_win_is_valid(preview.win) then
				pcall(vim.api.nvim_win_close, preview.win, true)
			end
			preview.win = nil
			preview.source_buf = nil
		end

		---@param opts table? `{ force = true }` 绕过 auto=false 的提前返回（手动 `p` 用）
		local function update_preview(opts)
			opts = opts or {}
			if not preview.auto and not opts.force then
				return
			end
			if vim.bo.filetype ~= "neominimap" then
				close_preview()
				return
			end
			local mwinid = vim.api.nvim_get_current_win()
			local mrow = vim.api.nvim_win_get_cursor(mwinid)[1]
			local layout = require("neominimap.config").layout

			local swinid
			if layout == "float" then
				swinid = require("neominimap.window.float.window_map").get_parent_winid(mwinid)
			else
				swinid = require("neominimap.window.split.window_map").get_source_winid(
					vim.api.nvim_get_current_tabpage()
				)
			end
			if not swinid or not vim.api.nvim_win_is_valid(swinid) then
				close_preview()
				return
			end
			local sbufnr = vim.api.nvim_win_get_buf(swinid)

			local srow = require("neominimap.map.coord").mcodepoint_to_codepoint(mrow, 1)
			local line_count = vim.api.nvim_buf_line_count(sbufnr)
			srow = math.max(1, math.min(srow, line_count))

			local mwidth = vim.api.nvim_win_get_width(mwinid)
			local pwidth = math.min(70, math.max(40, vim.o.columns - mwidth - 6))
			local pheight = math.min(20, math.max(8, vim.api.nvim_win_get_height(mwinid)))
			if pwidth < 30 then
				close_preview()
				return
			end

			-- 源 buffer 变化（用户在不同主窗间切了 minimap focus）就重建浮窗
			if not preview.win or not vim.api.nvim_win_is_valid(preview.win) or preview.source_buf ~= sbufnr then
				close_preview()
				preview.win = vim.api.nvim_open_win(sbufnr, false, {
					relative = "win",
					win = mwinid,
					anchor = "NE",
					row = 0,
					col = 0,
					width = pwidth,
					height = pheight,
					style = "minimal",
					border = "rounded",
					focusable = false,
					zindex = 50,
					noautocmd = true,
				})
				preview.source_buf = sbufnr
				vim.wo[preview.win].number = true
				vim.wo[preview.win].cursorline = true
				vim.wo[preview.win].foldenable = false
				vim.wo[preview.win].signcolumn = "no"
			end

			pcall(vim.api.nvim_win_set_cursor, preview.win, { srow, 0 })
			pcall(vim.api.nvim_win_call, preview.win, function()
				vim.cmd("normal! zz")
			end)
		end

		vim.api.nvim_create_autocmd("FileType", {
			pattern = "neominimap",
			desc = "Minimap focused-mode keymaps + preview popup",
			callback = function(args)
				local bufnr = args.buf
				local function commit_then_unfocus()
					local layout = require("neominimap.config").layout
					local internal = require("neominimap.window." .. layout .. ".internal")
					if layout == "float" then
						internal.reset_parent_window_cursor_line(vim.api.nvim_get_current_win())
					else
						internal.reset_parent_window_cursor_line()
					end
					close_preview()
					require("neominimap.api").focus.disable()
				end
				local function unfocus_only()
					close_preview()
					require("neominimap.api").focus.disable()
				end
				local function toggle_preview()
					if preview.win and vim.api.nvim_win_is_valid(preview.win) then
						close_preview()
					else
						update_preview({ force = true })
					end
				end
				local function toggle_auto_preview()
					preview.auto = not preview.auto
					vim.notify(
						"Minimap auto-preview: " .. (preview.auto and "ON" or "OFF"),
						vim.log.levels.INFO
					)
					if preview.auto then
						update_preview() -- 立刻按当前光标刷一帧
					end
				end
				local map = function(lhs, rhs, desc)
					vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
				end
				map("<CR>", commit_then_unfocus, "Minimap: jump to preview & return")
				map("q", unfocus_only, "Minimap: cancel & return")
				map("<Esc>", unfocus_only, "Minimap: cancel & return")
				-- p / P 对齐 trouble.nvim：p = 单次浮窗开关；P = 自动跟随模式开关。
				-- 这俩键在 normal vim 里默认是 paste（裸 buffer 是 braille，paste 也
				-- 没意义），覆盖无副作用。
				map("p", toggle_preview, "Minimap: toggle preview popup")
				map("P", toggle_auto_preview, "Minimap: toggle auto-preview")

				-- 浮窗事件：进 minimap / 移动光标 → 更新预览；离开 → 关掉。
				-- BufLeave 兜底——任何走 autocmd 路径离开 minimap buffer 的情况
				-- 都覆盖（包括 unfocus / 切 buffer / 关 minimap window 等）。
				local group = vim.api.nvim_create_augroup("UserMinimapPreview_" .. bufnr, { clear = true })
				vim.api.nvim_create_autocmd({ "CursorMoved", "WinEnter" }, {
					group = group,
					buffer = bufnr,
					callback = update_preview,
				})
				vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
					group = group,
					buffer = bufnr,
					callback = close_preview,
				})
			end,
		})
	end,
}
