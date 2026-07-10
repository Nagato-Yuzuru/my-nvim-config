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
				-- flatten 的 git commit 阻塞流程会快速开/关 COMMIT_EDITMSG 窗口，
				-- minimap float 在关窗竞态下会陈旧 window id 报错循环（实测）；
				-- 几行的 commit message 也用不上缩略图
				"gitcommit",
				"gitrebase",
				"lazy",
				"mason",
				"checkhealth",
				"TelescopePrompt",
				"TelescopeResults",
				"noice",
				"notify",
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
		-- 预览浮窗的状态机、幂等 teardown、key 去重、generation 竞态防护都在
		-- 共享的 tools.float_preview 里（和 lua/plugins/ui/snacks.lua 同源）。这里
		-- 只注入 neominimap 特有的三块：活 buffer 解析（source）、NE 锚定几何
		-- （geometry）、focused-mode 键与事件（全部宿主拥有——模块不订阅 autocmd）。
		local float_preview = require("tools.float_preview")

		-- source：把 minimap 当前光标行映射回源窗口的源 buffer + 源行。
		--
		-- **直接复用源 buffer**（不复制 lines 到 scratch）——treesitter 高亮 /
		-- folds / diagnostic 标记全自动正确，和主窗渲染完全一致；代价是
		-- BufWinEnter 之类 autocmd 会触发一遍（用 geometry 里的 noautocmd 规避）。
		--
		-- key = 源 bufnr：同一源 buffer 内 j/k 移动 → key 不变 → 只挪光标不重建
		-- （CursorMoved 高频路径廉价化）；切到别的主窗（源 buffer 变）→ key 变 →
		-- 换 buffer。返回 nil ⇒ 关闭（不在 minimap / 源窗口没了）。
		--
		-- 坐标转换用 map.coord 暴露的 mcodepoint_to_codepoint，把 minimap row
		-- 换算成源行，clamp 进源 buffer 行数。commit 分 layout 取源窗口：float
		-- 取 parent winid，split 从 tabpage 推断。
		local function minimap_source()
			if vim.bo.filetype ~= "neominimap" then
				return nil
			end
			local mwinid = vim.api.nvim_get_current_win()
			local mrow = vim.api.nvim_win_get_cursor(mwinid)[1]
			local layout = require("neominimap.config").layout

			local swinid
			if layout == "float" then
				swinid = require("neominimap.window.float.window_map").get_parent_winid(mwinid)
			else
				swinid =
					require("neominimap.window.split.window_map").get_source_winid(vim.api.nvim_get_current_tabpage())
			end
			if not swinid or not vim.api.nvim_win_is_valid(swinid) then
				return nil
			end
			local sbufnr = vim.api.nvim_win_get_buf(swinid)

			local srow = require("neominimap.map.coord").mcodepoint_to_codepoint(mrow, 1)
			local line_count = vim.api.nvim_buf_line_count(sbufnr)
			srow = math.max(1, math.min(srow, line_count))
			return { buf = sbufnr, key = sbufnr, cursor = { srow, 0 } }
		end

		-- geometry：anchor=NE, relative=win(mwinid), col=0, row=0 → 浮窗右上角贴
		-- minimap 左上角，整个出现在 minimap 左侧、顶部对齐。宽度按
		-- (columns - mwidth - 6) 算，留余量给主窗边距和圆角 border；太窄
		-- （pwidth < 30）→ 返回 nil ⇒ 空间不足 ⇒ 关闭。
		local function minimap_geometry()
			local mwinid = vim.api.nvim_get_current_win()
			local mwidth = vim.api.nvim_win_get_width(mwinid)
			local pwidth = math.min(70, math.max(40, vim.o.columns - mwidth - 6))
			local pheight = math.min(20, math.max(8, vim.api.nvim_win_get_height(mwinid)))
			if pwidth < 30 then
				return nil
			end
			return {
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
			}
		end

		-- auto = true 对齐 trouble.nvim 的 auto_preview 默认；状态跨 buffer 共享
		-- （一个会话一份，因为 preview 是 init closure-local）。
		local preview = float_preview.new({
			auto = true,
			source = minimap_source,
			geometry = minimap_geometry,
			wo = {
				number = true,
				cursorline = true,
				foldenable = false,
				signcolumn = "no",
			},
		})

		vim.api.nvim_create_autocmd("FileType", {
			pattern = "neominimap",
			desc = "Minimap focused-mode keymaps + preview popup",
			callback = function(args)
				local bufnr = args.buf
				-- commit 跳转要分 layout 调下层 internal——float / split 的
				-- reset_parent_window_cursor_line 签名不同（float 取 mwinid，split
				-- 不取参数从 tabpage 推断），neominimap.api 没暴露统一封装，所以这
				-- 里下沉一层。plugin 后续若加 api.commit 这种公开接口应切过去。
				local function commit_then_unfocus()
					local layout = require("neominimap.config").layout
					local internal = require("neominimap.window." .. layout .. ".internal")
					if layout == "float" then
						internal.reset_parent_window_cursor_line(vim.api.nvim_get_current_win())
					else
						internal.reset_parent_window_cursor_line()
					end
					preview:close()
					require("neominimap.api").focus.disable()
				end
				local function unfocus_only()
					preview:close()
					require("neominimap.api").focus.disable()
				end
				-- 宿主拥有 notify（文案是 minimap 特有的）；模块负责翻转 + 开启时
				-- 立刻刷一帧。
				local function toggle_auto_preview()
					local on = preview:toggle_auto()
					vim.notify("Minimap auto-preview: " .. (on and "ON" or "OFF"), vim.log.levels.INFO)
				end
				local map = function(lhs, rhs, desc)
					vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
				end
				map("<CR>", commit_then_unfocus, "Minimap: jump to preview & return")
				map("q", unfocus_only, "Minimap: cancel & return")
				map("<Esc>", unfocus_only, "Minimap: cancel & return")
				-- p / P 对齐 trouble.nvim：p = 单次浮窗开关（toggle，强制，绕过
				-- auto）；P = 自动跟随模式开关。这俩键在 normal vim 里默认是 paste
				-- （裸 buffer 是 braille，paste 也没意义），覆盖无副作用。
				map("p", function() preview:toggle() end, "Minimap: toggle preview popup")
				map("P", toggle_auto_preview, "Minimap: toggle auto-preview")

				-- 浮窗事件全部宿主拥有（模块不订阅 autocmd）：进 minimap / 移动光标
				-- → show_auto（受 auto 门控）；离开 → close。BufLeave 兜底——任何走
				-- autocmd 路径离开 minimap buffer 的情况都覆盖（unfocus / 切 buffer /
				-- 关 minimap window 等）。
				local group = vim.api.nvim_create_augroup("UserMinimapPreview_" .. bufnr, { clear = true })
				vim.api.nvim_create_autocmd({ "CursorMoved", "WinEnter" }, {
					group = group,
					buffer = bufnr,
					callback = function() preview:show_auto() end,
				})
				vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
					group = group,
					buffer = bufnr,
					callback = function() preview:close() end,
				})
			end,
		})
	end,
}
