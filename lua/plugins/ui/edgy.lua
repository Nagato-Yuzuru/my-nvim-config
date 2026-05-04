-- edgy.nvim — 边缘 dock 管理器（folke 出品，和 Trouble/Snacks/which-key/lazy
-- 同一作者）。把 bottom / right 边上互相挤占的 split 类 panel 改造成"带 tab
-- 的 dock"：同一边可放多个 panel，自动切换显示，不再 stack 互相挤压。
--
-- 为什么要装：
--   Trouble + toggleterm + qf + help 都想占底部一条 dock，不装 edgy 会出现
--   stack（多个 panel 上下挤）或互相覆盖。right 边 Aerial 单兵，没这个问题
--   也写进来求个统一管理。
--
-- 边界（业界 allowlist 模式）：
-- edgy 结构上只支持 allowlist——只接管下面 spec 里声明的 ft，未声明的一律
-- 不动（edgebar.lua:146 的 wins[view.ft] lookup）。所以"哪些不走 edgy"=
-- "没写进 spec 的"，没有 deny-list 概念。判据是：**这个插件的窗口之间有没
-- 有'必须挨着对方'的拓扑依赖？**有就别写进来：
--   * Overseer：list + output 必须 vsplit 相邻（overseer/window.lua:18-34），
--     edgy 把 list 拽走会碎。让 overseer 自己 layout。
--   * dap-ui：4 个 element 互相独立没拓扑依赖，**结构上能塞进 edgy**，但 dap-ui
--     有自己精心配的 size 比例（scopes 0.40 / 其它 0.20）和 position；交给 edgy
--     管会被 view 的 size 字段全覆盖。再加上和 Aerial 抢 right edge 的高度，
--     整体不划算——让 dap-ui 走自己的 layout（lua/plugins/runtime/dap.lua）。
--   * Snacks Explorer：用 Snacks 自己的 layout 系统，独占 left edge 不冲突。
--   * Snacks pickers / 浮窗：edgy 默认不管 floating window，pickers 照旧浮起来。
--     **例外**：如果浮窗的 ft 和 spec 里某个 view 重名（trouble 预览就是这种，
--     ft 仍是 "trouble"），edgy 会把它 demote 成 dock split——这种用 filter 排除。
--   * 普通编辑窗口：edgy 只匹配下面声明的 ft，其它一律不动。
--
-- 关于 init：
--   edgy 文档建议 laststatus = 3（global statusline）+ splitkeep = "screen"，
--   这样 dock 开关时不会让光标位置/状态栏跳动。

return {
	"folke/edgy.nvim",
	event = "VeryLazy",
	init = function()
		vim.opt.laststatus = 3
		vim.opt.splitkeep = "screen"
	end,
	opts = {
		bottom = {
			{
				ft = "trouble",
				title = "Trouble",
				size = { height = 0.3 },
				-- 排除预览浮窗——edgy 的 edgebar 看到 ft = "trouble" 就会把浮窗
				-- demote 成 dock split（edgebar.lua:204 "make floating windows
				-- normal windows"），让我们配的 preview.type = "float" 失效。
				-- 注意：trouble 在预览窗上设的 vim.w[win].trouble_preview 标记是
				-- 在 :open() 之后才打的（preview.lua:162），edgy 的 autocmd 早于
				-- 那一步触发，所以判 trouble_preview 太晚。改用更早就成立的判据：
				-- 主窗是 split (`relative == ""`)、预览是 float (`relative ~= ""`)。
				-- 同 toggleterm filter 的套路。
				filter = function(_buf, win)
					return vim.api.nvim_win_get_config(win).relative == ""
				end,
			},
			-- Overseer 不入 edgy：它原生用 botright split + belowright vsplit
			-- 出"左 list 右 output"的并列 layout（overseer/window.lua:18-34），
			-- list 和 output（ft = OverseerOutput）必须保持 vsplit 相邻。
			-- edgy 只识别 OverseerList，把 list 拖到 dock edge 会打散这个拓扑。
			-- 留给 overseer 自己 layout。
			{
				ft = "toggleterm",
				title = "Terminal",
				size = { height = 0.3 },
				-- toggleterm 创建窗口时 size 已固定；让 edgy 接管时用我们这里的值。
				filter = function(_buf, win)
					return vim.api.nvim_win_get_config(win).relative == ""
				end,
			},
			{ ft = "qf", title = "QuickFix" },
			-- dap-repl / dapui_console 不入 edgy：dap-ui layout 2 (`bottom`) 把这俩
			-- 配成左右并排独占底部 27%，dap-ui open/close 时整组开关；交给 edgy 会
			-- 拆散这个语义。让 dap-ui 自己 layout。
			{
				ft = "help",
				title = "Help",
				size = { height = 0.5 },
				-- 只把 :help 触发的 help buffer 收进 dock；其它伪装成 help 的 ft 放过。
				filter = function(buf)
					return vim.bo[buf].buftype == "help"
				end,
			},
		},
		right = {
			{ ft = "aerial", title = "Aerial", size = { width = 0.25 } },
			-- dap-ui 的 4 个 right element（scopes / breakpoints / stacks / watches）
			-- 不进来——见上面顶部注释里"dap-ui"那条。
		},
		-- 关掉默认的 animate（开着的话切 dock tab 会有滑入/滑出效果，
		-- 在 split 切换频繁时显得拖沓；想要的话改回 true）。
		animate = { enabled = false },
		-- edgy 默认在它管的 buffer 内加一组窗口本地键位，用来在 dock 内
		-- 导航、关窗、调宽高（见 edgy/config.lua:62 起）。
		-- edgy 显式承诺"不覆盖已有的 buffer-local 键"（同文件第 59 行注释），
		-- 所以让 Trouble/Overseer/DAP UI 自己的 q/<cr>/j/k 优先，剩下的位才
		-- 由 edgy 接手。保留默认即可：
		--   q          关当前 dock 内的窗口（trouble/overseer 自己绑了 q，
		--              所以这条只在没绑的 dock 窗口上生效）
		--   <C-q>      隐藏当前窗口（dock 里其它 tab 顶上来）
		--   Q          关掉整条 dock
		--   ]w / [w    跳到同一 dock 的下/上一个**已打开**窗口
		--   ]W / [W    跳到同一 dock 的下/上一个**已加载**窗口（含未显示）
		--   <C-w>+/-/>/<   调高度/宽度（单击式，需要按 chord）
		--   <C-w>=     重置该 dock 内所有自定义尺寸
		--
		-- resize 长按需求统一交给 hydra（lua/plugins/ui/hydra.lua）的
		-- <leader>w body —— 不在 edgy / 各 dock buffer 里散落裸键别名，
		-- 单一来源；hydra body 在任何 normal-mode buffer 里都能进，pink
		-- 模式下的 head 是 buffer-local，dock buffer 里照样响应。
	},
}
