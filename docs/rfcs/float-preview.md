## Problem

同一个概念 —— **由宿主生命周期钩子驱动的、closure 管理的浮动预览窗** —— 在两处独立实现了两遍：

- `lua/plugins/ui/snacks.lua`（~500 行，占该文件 766 行的 2/3）：explorer 预览。二进制检测 → scratch buffer 加载（大小护栏）→ float 几何 → 焦点跟踪 → 节流竞态防护（光标移走后旧异步回调晚到）。
- `lua/plugins/ui/neominimap.lua:191-330`（~140 行）：同一套状态机（closure state / close_preview / update_preview / 几何 / `p`/`P` 键），区别仅在于复用活 buffer 而非复制进 scratch。

snacks.lua 的注释自己承认镜像关系（"Mirrors lua/plugins/ui/neominimap.lua"）。两处各自踩过同样的坑（stale 异步更新、窗口有效性、幂等 teardown），修 bug 要修两遍。这是典型的浅模块摩擦：接口（两组内联 closure）几乎和实现一样复杂，且集成风险藏在两份拷贝的缝隙里。

## Proposed Interface

三个候选设计（最小接口 / 最大灵活性 / 常见调用方优化）对比后的**混合方案**：取"常见调用方优化"的形态 + "最小接口"的纪律，砍掉"最大灵活性"的策略族（无第三个具体调用方，属投机通用性）。

```lua
-- lua/tools/float_preview.lua

---@class FloatPreview.Content
---@field buf integer        -- 要展示的 buffer
---@field key any            -- 身份标识；key 相同且 float 存活 ⇒ 只重定位，不重建
---@field cursor? integer[]  -- {row, col}（1-based），展示后置光标并 zz 居中

---@class FloatPreview.Opts
---@field source? fun(req: any): FloatPreview.Content|nil
---       缺省实现 = 只读 scratch 文件预览管线（NUL 二进制检测、字节/行数上限、
---       filetype.match、bufhidden=wipe 自清理）。返回 nil ⇒ 不可预览 ⇒ 关闭。
---@field geometry fun(): vim.api.keyset.win_config|nil  -- 每个调用方显式提供；nil ⇒ 空间不足 ⇒ 关闭
---@field wo? table<string, any>    -- 窗口局部选项，随开窗应用
---@field on_show? fun(buf: integer, self: FloatPreview)  -- 每次 (重)建 buffer 后回调（绑 buffer-local 键）
---@field auto? boolean             -- auto-follow 初始状态

local M = {}
---@param opts FloatPreview.Opts
---@return FloatPreview
function M.new(opts) end

function FP:show(req) end          -- 强制显示；source 返回 nil 则关闭并返回 false
function FP:show_auto(req) end     -- 受 auto 门控的 show（宿主 CursorMoved/on_change 里调）
function FP:toggle(req) end        -- `p` / <A-p>
function FP:toggle_auto(req) end   -- `P`；开启时立即刷新
function FP:mute(key) end          -- 一次性吸收下一个携带该 key 的 show_auto（commit 后的节流回火）
function FP:close() end
function FP:is_open() end
function FP:win() end              -- 活 float winid，宿主 commit/focus 用
function FP:scroll(dir) end        -- "up"|"down"（两个调用方都要，非投机）
```

调用方示意：

```lua
-- snacks explorer：默认 source，接近零配置
local preview = require("tools.float_preview").new({
	geometry = editor_centered_cfg, -- 显式；不做"侧栏形状"的默认几何
	on_show = bind_float_keys,
})
sources.explorer.on_change = function(_, item)
	if not explorer_focused() then return end -- 宿主特有的焦点门控留在宿主
	preview:show_auto(item and not item.dir and item.file or nil)
end

-- neominimap：覆盖 source（复用活 buffer）+ 自己的 NE 锚定几何
local preview = require("tools.float_preview").new({
	auto = true,
	source = function() ... return { buf = sbuf, key = sbuf, cursor = { srow, 0 } } end,
	geometry = ne_anchored_cfg,
})
-- FileType=neominimap 回调里：p → toggle，P → toggle_auto，CursorMoved → show_auto，WinLeave → close
```

模块内部隐藏的复杂度：win/buf/key 状态机与幂等 teardown；开窗 vs `nvim_win_set_buf` 原地换 buffer 的决策；key 去重（相同 key 只挪光标，CursorMoved 高频路径廉价化）；单调 generation 的 stale 防护（show/close 各自 bump，晚到的结果被丢弃）；缺省 scratch 管线全套护栏；`mute` 一次性吸收。

**硬约束**（三个设计共同确认）：
1. buffer 策略（scratch 复制 vs 活 buffer）是参数，不是对调用方身份的 if/else；
2. 模块不订阅任何 autocmd/事件 —— 生命周期归宿主，模块只暴露命令式原语；
3. 竞态防护必须在共享层。

## Dependency Strategy

**In-process**（纯 Neovim API：`vim.api` / `vim.uv` / `vim.fn` / `vim.filetype`）—— 直接合并为 `lua/tools/` 下的普通模块（与 `lsp_root.lua`、`mason_install.lua` 同风格），零插件耦合：模块内不 `require` snacks 或 neominimap，宿主特有逻辑全部经 `source`/`geometry`/`on_show` closure 注入。

## Testing Strategy

- **新的边界测试**：headless nvim（`nvim -l tests/float_preview_spec.lua`）直接驱动真实 buffer/window，零 mock。断言：`show(真实路径)` → scratch 只读/行数/filetype 正确；二进制/超限文件 → 返回 false 且窗口关闭；相同 key 连续 `show_auto` → 不重建窗口（winid 不变）；`mute(k)` 吸收恰好一次；`show(a)` 后 `show(b)`，再补投 a 的 generation → 被丢弃；`close` 幂等。
- **可删的旧测试**：无（本配置没有测试套件——这正是收益之一：两份内联实现原本不可测，收拢后的模块第一次变得可直接测试）。
- **测试环境**：headless nvim 即可，无外部依赖。

## Implementation Recommendations

- **模块拥有**：float 生命周期与状态、缺省 scratch 加载管线、key 去重、generation 竞态防护、mute。
- **模块隐藏**：winid/bufnr 记账、开窗-换 buffer 决策、pcall 防御、光标放置。
- **模块暴露**：上面 9 个方法的 controller 契约 —— 每个方法都被两个现有调用方同时使用，无一投机。
- **明确不做**（来自三方案对比的否决项）：strategy/geometry 内置策略族与注册表（等第三个具体调用方出现再说）；模块内事件订阅；"侧栏形状"的默认几何（过度特化，几何始终显式）。
- **迁移顺序**：先 snacks（收益最大，766 → ~300 行），后 neominimap（−~120 行）；snacks 的 `fold_*` 辅助函数与预览无关，原地保留；宿主侧的 `explorer_focused()` 门控与 commit 语义留在宿主（模块不拥有事件，设计使然）。
- 每个调用方迁移后用上述 headless 断言 + 手动冒烟（explorer 移动/`<A-p>`/`<CR>` commit；minimap `p`/`P`/CursorMoved）验证行为等价。

---
设计过程：3 个独立设计 agent（最小接口 / 最大灵活性 / 常见调用方优化）各自读两份实现后产出方案，本 RFC 为对比综合。

🤖 Generated with [Claude Code](https://claude.com/claude-code)
