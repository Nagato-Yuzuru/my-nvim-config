-- nvim-dap suite —— plugin spec、键位、UI/sign。
--
-- ► Per-adapter 配置在顶层 `dap/<adapter>.lua`（镜像 `lsp/<server>.lua`），
--   由 `lua/core/dap.lua` 加载。新增 adapter = 在 `dap/` 下放一个文件，**不要**
--   在这里堆（CLAUDE.md "Architecture" 段同此约束）。
--
-- ► 安装走 mason-registry 直连（core.dap.ensure_mason），不依赖 mason-nvim-dap。
--
-- 键位按"需要的时机"双层分布（完整表见下方 keys = {} 列表与文件后段的
-- `actions` 表）：
--   * 静态 <leader>d*  编辑态 / 生命周期 / 面板焦点（永远在）
--   * 动态 ,*          运行态控制与观察（dap.listeners 在 session 内动态绑）
-- 严格单归属：`dc/dn/ds/df/dr/de/dh/dj/dk/dR` 不在静态层，只在 session 内
-- 通过 ,c/,n/,s/,f/,r/,e/,h/,j/,k/,R 生效。

local function inspect_expr() require("dapui")["eval"](nil, { enter = true }) end

-- <leader>dt：设置 logpoint（DAP 里叫 "breakpoint with logMessage"）。
-- 不暂停、只在命中时把消息打到 REPL/console。消息里可用 `{expr}` 语法插值。
local function set_logpoint()
	vim.ui.input({ prompt = "Log message (use {expr} to interpolate): " }, function(msg)
		if msg and msg ~= "" then
			require("dap").set_breakpoint(nil, nil, msg)
		end
	end)
end

-- <leader>dF：函数断点（toggle）。输入空名触发 list 已有的。
local function toggle_function_breakpoint_ui()
	vim.ui.input({ prompt = "Function name (empty = list current): " }, function(name)
		local core_dap = require("core.dap")
		if not name or name == "" then
			local list = core_dap.list_function_breakpoints()
			vim.notify(
				#list > 0 and ("Function BPs:\n" .. table.concat(list, "\n")) or "(no function breakpoints)",
				vim.log.levels.INFO
			)
			return
		end
		core_dap.toggle_function_breakpoint(name)
	end)
end

-- <leader>dA：从当前 filetype 的 configurations 里挑 attach / core-dump / remote
-- 条目，`vim.ui.select` 出来执行。
local function attach_picker()
	local dap = require("dap")
	local ft = vim.bo.filetype
	local configs = dap.configurations[ft] or {}
	local candidates = {}
	for _, cfg in ipairs(configs) do
		local name_lower = (cfg.name or ""):lower()
		if
			cfg.request == "attach"
			or cfg.mode == "core"
			or cfg.mode == "remote"
			or name_lower:find("core")
			or name_lower:find("remote")
		then
			table.insert(candidates, cfg)
		end
	end
	if #candidates == 0 then
		vim.notify("No attach/core/remote configs for ft=" .. ft, vim.log.levels.WARN)
		return
	end
	vim.ui.select(candidates, {
		prompt = "Select attach/core/remote config:",
		format_item = function(item) return item.name or "(unnamed)" end,
	}, function(choice)
		if choice then
			dap.run(choice)
		end
	end)
end

-- <leader>dv{s,t,b,w,c,r}：把焦点切到 dap-ui layout 里对应的面板窗口。
-- 不用 dapui.float_element —— 它的自动尺寸遇到长 scope/stack 会触发 E36
-- (Not enough room)。直接按 filetype 找已打开的面板窗口，找不到就先开 layout
-- 再试。绝大多数元素的 filetype 模板是 `dapui_<element>`；`repl` 例外，走 nvim-dap
-- 本体的 `dap-repl`。
local function focus_dapui_panel(element_id)
	local target_ft = (element_id == "repl") and "dap-repl" or ("dapui_" .. element_id)
	local function try_focus()
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.bo[buf].filetype == target_ft then
				vim.api.nvim_set_current_win(win)
				return true
			end
		end
		return false
	end
	if try_focus() then
		return
	end
	require("dapui").open()
	vim.defer_fn(function()
		if not try_focus() then
			vim.notify("dap-ui panel not found: " .. element_id, vim.log.levels.WARN)
		end
	end, 50)
end

-- <leader>dw / ,w：把光标下单词或 visual 选区加入 Watches。
local function add_watch_from_source()
	local mode = vim.fn.mode()
	local expr
	if mode == "v" or mode == "V" or mode == "\22" then
		-- yank 到 "v" 寄存器（不碰 unnamed 寄存器），退出 visual 后读回来
		vim.cmd('normal! "vy')
		expr = vim.fn.getreg("v")
	else
		expr = vim.fn.expand("<cword>")
	end
	if not expr or expr == "" then
		return
	end
	local ok, dapui = pcall(require, "dapui")
	if not (ok and dapui.elements and dapui.elements.watches) then
		vim.notify("dap-ui watches not ready — open DAP UI first (<leader>vd)", vim.log.levels.WARN)
		return
	end
	dapui.elements.watches.add(expr)
	vim.notify(("Watch: %s"):format(expr), vim.log.levels.INFO)
end

return {
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"rcarriga/nvim-dap-ui",
			"nvim-neotest/nvim-nio",
			"theHamsta/nvim-dap-virtual-text",
			"williamboman/mason.nvim",
		},
		keys = {
			-- === 生命周期 / 启动 ===
			{ "<leader>D", function() require("dap").continue() end, desc = "Debug: start / continue" },
			{ "<leader>dl", function() require("dap").run_last() end, desc = "Run last" },
			{ "<leader>dA", attach_picker, desc = "Attach / core / remote picker" },
			{ "<leader>dq", function() require("dap").terminate() end, desc = "Terminate session (escape hatch)" },

			-- === 断点类型（编辑态设置） ===
			{ "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
			{
				"<leader>dB",
				function()
					vim.ui.input({ prompt = "Breakpoint condition: " }, function(cond)
						if cond and cond ~= "" then
							require("dap").set_breakpoint(cond)
						end
					end)
				end,
				desc = "Conditional breakpoint",
			},
			{ "<leader>dF", toggle_function_breakpoint_ui, desc = "Function breakpoint (toggle)" },
			{ "<leader>dt", set_logpoint, desc = "Logpoint (tracepoint)" },
			{
				"<leader>dX",
				function() require("dap").set_exception_breakpoints() end,
				desc = "Exception filter picker",
			},

			-- === UI / 面板焦点 ===
			{ "<leader>vd", function() require("dapui").toggle() end, desc = "Toggle DAP UI" },
			-- 被其它 panel 挤过尺寸后，把 dap-ui 弹回原始 layout 比例。
			-- 走 `dapui.open({ reset = true })`：内部会把 area_state.size 重置回
			-- init_size（dapui/windows/layout.lua:84），其它逻辑 no-op（is_open 跳过）。
			-- 试过 WinClosed 自动触发的版本——snacks picker 等一些插件关窗时 buffer
			-- 会被立刻 wipe，buf 失效让 autocmd 走不到 schedule；又抓不到一个对所有
			-- 关窗路径都稳定的事件，干脆只留手动键。
			{ "<leader>d=", function() require("dapui").open({ reset = true }) end, desc = "Reset DAP UI sizes" },
			-- 面板聚焦：s/t/b/w 是 layout 左侧四板，c/r 是底部两板。
			-- 助记：Scopes / sTack / Breakpoints / Watches / Console / Repl
			{ "<leader>dvs", function() focus_dapui_panel("scopes") end, desc = "Focus Scopes panel" },
			{ "<leader>dvt", function() focus_dapui_panel("stacks") end, desc = "Focus Callstack panel" },
			{ "<leader>dvb", function() focus_dapui_panel("breakpoints") end, desc = "Focus Breakpoints panel" },
			{ "<leader>dvw", function() focus_dapui_panel("watches") end, desc = "Focus Watches panel" },
			{ "<leader>dvc", function() focus_dapui_panel("console") end, desc = "Focus Console panel" },
			{ "<leader>dvr", function() focus_dapui_panel("repl") end, desc = "Focus REPL panel" },
			-- Note: "add watch from source" 是运行态动作，只在动态层 ,w 绑。
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			-- Sign column 标识 ----------------------------------------------------
			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError", linehl = "", numhl = "" })
			vim.fn.sign_define(
				"DapBreakpointCondition",
				{ text = "◆", texthl = "DiagnosticWarn", linehl = "", numhl = "" }
			)
			vim.fn.sign_define(
				"DapBreakpointRejected",
				{ text = "○", texthl = "DiagnosticHint", linehl = "", numhl = "" }
			)
			vim.fn.sign_define("DapLogPoint", { text = "◉", texthl = "DiagnosticInfo", linehl = "", numhl = "" })
			vim.fn.sign_define(
				"DapStopped",
				{ text = "▶", texthl = "DiagnosticOk", linehl = "DapStoppedLine", numhl = "" }
			)

			-- dap-ui 自动开关 -----------------------------------------------------
			dap.listeners.before.attach.dapui_config = function() dapui.open() end
			dap.listeners.before.launch.dapui_config = function() dapui.open() end
			dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
			dap.listeners.before.event_exited.dapui_config = function() dapui.close() end

			-- 加载所有 dap/<adapter>.lua，安装缺失的 mason 包 -------------------
			local core_dap = require("core.dap")
			local mason_pkgs = core_dap.setup()
			core_dap.ensure_mason(mason_pkgs)

			-- 新 session 启动时，把持久化的函数断点重新 apply ------------------
			dap.listeners.after.event_initialized["function_breakpoints"] = function()
				core_dap.apply_function_breakpoints()
			end

			-- dap-virtual-text：行内显示当前 frame 的局部变量值
			require("nvim-dap-virtual-text").setup({
				enabled = true,
				commented = true,
				virt_text_pos = "eol",
			})

			-- dap-ui ----------------------------------------------------------------
			dapui.setup({
				layouts = {
					{
						elements = {
							{ id = "scopes", size = 0.40 },
							{ id = "breakpoints", size = 0.20 },
							{ id = "stacks", size = 0.20 },
							{ id = "watches", size = 0.20 },
						},
						size = 40,
						position = "left",
					},
					{
						elements = {
							{ id = "repl", size = 0.5 },
							{ id = "console", size = 0.5 },
						},
						size = 0.27,
						position = "bottom",
					},
				},
				floating = { border = "rounded" },
			})

			-- ====================================================================
			-- 动态层 ,*  —— 只在 session 内存在的运行态动作
			-- ====================================================================
			-- Action 表是运行态动作的唯一真相源。`<leader>d*` 静态层里不再重复
			-- 绑定这些动作（见 CLAUDE.md）。
			-- 描述风格对齐 `,g*` (Git) / `,l*` (LeetCode) 的 "domain: action" 风格，
			-- 方便 which-key 在 `,` 根菜单里一眼看出这一坨是 session-scoped debug。
			--
			-- 键位用 CLI-debugger 助记符，不用 F-keys：`,n`/`,s`/`,f` 直接对应
			-- pdb / dlv / gdb 的 `n` (next/step over) / `s` (step into) / `f`
			-- (finish/step out)；`,c` continue、`,p` pause、`,u` run-to-cursor
			-- (until)、`,r` toggle REPL、`,e` inspect expression、`,h` hover
			-- 变量、`,w` add watch、`,j`/`,k` frame down/up、`,R` restart、
			-- `,q` terminate。F-keys (JetBrains 风格) 故意不绑：leader/localleader
			-- 用 Vim 语法、跨键盘布局可达。
			local actions = {
				c = { fn = function() dap.continue() end, desc = "Debug: Continue" },
				n = { fn = function() dap.step_over() end, desc = "Debug: Step over (next)" },
				s = { fn = function() dap.step_into() end, desc = "Debug: Step into" },
				f = { fn = function() dap.step_out() end, desc = "Debug: Step out (finish)" },
				p = { fn = function() dap.pause() end, desc = "Debug: Pause" },
				u = { fn = function() dap.run_to_cursor() end, desc = "Debug: Run to cursor (until)" },
				q = { fn = function() dap.terminate() end, desc = "Debug: Terminate session" },
				r = { fn = function() dap.repl.toggle() end, desc = "Debug: Toggle REPL" },
				e = {
					fn = inspect_expr,
					desc = "Debug: Inspect expression",
					mode = { "n", "v" },
				},
				h = { fn = function() require("dap.ui.widgets").hover() end, desc = "Debug: Hover variable" },
				w = {
					fn = add_watch_from_source,
					desc = "Debug: Add watch from source",
					mode = { "n", "v" },
				},
				j = { fn = function() dap.down() end, desc = "Debug: Frame down" },
				k = { fn = function() dap.up() end, desc = "Debug: Frame up" },
				R = { fn = function() dap.restart() end, desc = "Debug: Restart session" },
			}

			local function attach_localleader()
				for k, v in pairs(actions) do
					vim.keymap.set(v.mode or "n", "<localleader>" .. k, v.fn, { desc = v.desc })
				end
			end

			local function detach_localleader()
				for k, v in pairs(actions) do
					local modes = v.mode or "n"
					if type(modes) ~= "table" then
						modes = { modes }
					end
					for _, m in ipairs(modes) do
						pcall(vim.keymap.del, m, "<localleader>" .. k)
					end
				end
			end

			-- 生命周期挂 on_session（:h dap-listeners-on_session）而非 event_terminated/
			-- event_exited：before.* 阶段全局 session 必然还指着将亡 session（默认
			-- handler close 之后才清），按 dap.session() 判空的 detach 永远短路 →
			-- 键位泄漏；且 terminate/disconnect 存在不发 terminated 事件的路径。
			-- on_session 由 set_session 触发，覆盖启动/终止/崩溃/焦点切换全部路径；
			-- new == nil 才是真无 session——多 root session 时 set_session 会回退到
			-- 下一个活 session，子 session 关闭不触发全局变更，天然保住嵌套场景。
			dap.listeners.on_session["localleader_keys"] = function(_, new_session)
				if new_session then
					attach_localleader()
				else
					detach_localleader()
				end
			end
		end,
	},
}
