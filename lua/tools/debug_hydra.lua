-- Debug 步进 hydra —— 断点停住时的 sticky 子模式：裸键连按步进，屏上常驻
-- cheat sheet。生命周期由 DAP session 事件驱动（plugins/runtime/dap.lua 挂
-- 的 listeners 调 activate/exit），不注册全局 body 键 —— session 外零占用。
--
-- 为什么不放 plugins/ui/hydra.lua（hydra 总册）：那里的 hydra 是"构造即注册
-- 静态 body"的键位；这只是事件驱动 + 惰性构造 + 需要测试的逻辑，按 tools/
-- 惯例落这里。
--
-- 设计要点：
--   * bodyless Hydra —— 只能经 activate() 进入。入口两个：event_stopped
--     自动激活（低频用户零记忆成本），`,d`（session actions 表）手动重入。
--   * color = "pink" —— 非 head 键正常放行：停在断点上仍可移动光标 / gd /
--     滚动看代码，这正是"边步进边理解代码"的场景。代价：激活期间
--     n/s/f/c/u/J/K/. 八个普通键被借走（Esc 归还）。dap-ui 面板等
--     buffer-local 键优先级高于 layer 的全局映射，不受影响。
--   * heads 只收"会连按"的键；一次性动作（eval/hover/watch/quit）留在 `,*`
--     原位，pink 下照常可用，hint 里列出提醒。heads 是 `,*` actions 表
--     （plugins/runtime/dap.lua，session 键 SSOT）中步进子集的裸键别名 ——
--     改动作时两处同步。
--   * nowait = true —— pink hydra 的 head 不带它会等 timeoutlen（见
--     plugins/ui/hydra.lua 头注释的 pink 说明）。
--   * active 标志由 on_enter/on_exit 维护，不摸 hydra 私有状态；同时挡掉
--     每次 step 落地 event_stopped 重复触发的 re-activate（hint 不闪）。

local M = {}

---@type table? 惰性构造的 Hydra 实例；nil = 尚未构造（或 hydra.nvim 缺失）
local instance
local active = false
-- hydra.nvim 缺失时只警告一次、之后 activate 静默降级（`,*` 键仍可用）——
-- event_stopped 每步都触发，不能每停一次刷一条 warn。
local build_failed = false

-- hint 记法：`_x_` 渲染为高亮的 head 键。
local HINT = [[
 _n_ step over   _s_ step into   _f_ step out    _c_ continue
 _u_ to cursor   _J_ frame ↓     _K_ frame ↑     _._ exec point
 one-shot: ,e eval  ,h hover  ,w watch  ,q kill  ,Q detach │ Esc exit
]]

local function build()
	local ok, Hydra = pcall(require, "hydra")
	if not ok then
		build_failed = true
		vim.notify("debug_hydra: hydra.nvim not available — falling back to `,*` keys", vim.log.levels.WARN)
		return nil
	end
	local dap = require("dap")
	return Hydra({
		name = "Debug",
		mode = "n",
		hint = HINT,
		config = {
			color = "pink",
			hint = {
				type = "window",
				position = "bottom",
				float_opts = { border = "rounded" },
			},
			on_enter = function() active = true end,
			on_exit = function() active = false end,
		},
		heads = {
			{ "n", function() dap.step_over() end, { nowait = true, desc = "step over" } },
			{ "s", function() dap.step_into() end, { nowait = true, desc = "step into" } },
			{ "f", function() dap.step_out() end, { nowait = true, desc = "step out" } },
			{ "c", function() dap.continue() end, { nowait = true, desc = "continue" } },
			{ "u", function() dap.run_to_cursor() end, { nowait = true, desc = "run to cursor" } },
			{ "J", function() dap.down() end, { nowait = true, desc = "frame down" } },
			{ "K", function() dap.up() end, { nowait = true, desc = "frame up" } },
			{ ".", function() dap.focus_frame() end, { nowait = true, desc = "back to exec point" } },
			{ "<Esc>", nil, { exit = true, nowait = true, desc = "exit" } },
		},
	})
end

---event_stopped / `,d` 入口。已激活或非 normal 模式（插入态敲 REPL、
---visual 选区中停住）时静默跳过 —— 下一次停点或手动 `,d` 再进。
function M.activate()
	if active or build_failed then
		return
	end
	if vim.fn.mode() ~= "n" then
		return
	end
	if not instance then
		instance = build()
	end
	if instance then
		instance:activate()
	end
end

---session 结束（on_session → nil）时强制退出，防 layer/hint 泄漏到无
---session 状态。未构造 / 未激活时是 no-op。
function M.exit()
	if not (instance and active) then
		return
	end
	if instance.layer then
		-- 上游 bug（nvimtools/hydra.nvim @ pin 8c4a9f6）：`Hydra:activate()`
		-- 对 pink 有 `self.layer` 分支，`Hydra:exit()` 没有——只关 hint、跑
		-- on_exit，layer 的 head 映射永久泄漏在 buffer 里。`layer:exit()` 才是
		-- <Esc> exit-head 走的完整 teardown（还原映射 + hint + on_exit 链）。
		-- 上游修复后退回 instance:exit()。
		instance.layer:exit()
	else
		instance:exit()
	end
end

return M
