-- nvimtools/hydra.nvim — sticky chord 子模式框架
--
-- 注意 fork：原版 anuvyklack/hydra.nvim 自 2023-11 起停更，对 Neovim 0.11
-- 有未修的 bug。nvimtools 接管 orphan 插件（none-ls.nvim 同源），fork 已
-- 修 0.11 兼容（commit 394744a, v1.0.3）。**用就用 fork，不要碰原版。**
--
-- ── hydra 是什么 ─────────────────────────────────────────────────────────
-- "按一次 body+head 进入子模式，模式里裸键继续生效"——nvim 版的 tmux
-- `bind-key -r`。Resize 只是第一个用例，以后任何"反复按、不想每次加前缀"
-- 的工作流都能装成 hydra（git hunk 巡航、诊断巡航、buffer 切换等）。
--
-- ── 关键设计点 ──────────────────────────────────────────────────────────
--
-- 1. **body = `<C-w>`，复用 Vim 自带的 window-prefix**
--    README 开篇的 pragmatic 例子就是这种 (`<C-w>+++++--<<<<`)。和 Vim
--    内建命令完全兼容：
--      <C-w> 单按       → 保持 Vim 原本 window-prefix，等待下一键
--      <C-w>{h,j,k,l}   → focus（Vim 内建，不进 hydra）
--      <C-w>{v,s,q,...} → split/close（Vim 内建，不进 hydra）
--      <C-w>{+,-,>,<,=} → 立刻 resize **并**进入 hydra（之后裸键继续）
--    不需要新增 `<leader>w` 入口——共用一个前缀，肌肉记忆和 Vim 一致。
--
-- 2. **`invoke_on_body = false`（默认）**
--    这是上面共存的关键。如果设 true，单按 `<C-w>` 就会进入 hydra 子模式，
--    Vim 的 `<C-w>h/v/s/q` 等内建命令全部失效。设 false 则只有
--    `<C-w>+head` 才进入，body 单按 fall through 到 Vim 内建。
--
-- 3. **`color = "red"`（默认）**
--    red 的语义：head 继续 hydra，**非 head 键干净退出 hydra 并执行原意**。
--    这正符合 resize 工作流——按完一串 `++--` 想换去做别的事时，下一个
--    陌生键直接退出，不会粘在 hydra 状态里。
--    （pink 是 layer，会让非 head 键边运行边保留 hydra；语义反直觉，且
--    长按需要每个 head 显式 `nowait = true`，对 resize 不必要。）
--
-- 4. **`event = "VeryLazy"`**
--    hydra 体积小，body 又是常按键——VeryLazy 时一次性把 body+head 注册
--    好，绕开 lazy.nvim 的 `keys` 懒加载里"stub→`<Ignore>`+lhs 回放"的
--    时序，第一次按下行为就稳定。
--
-- 5. **`hint` 走默认 cmdline**（不显式 false）
--    cmdline 自动 hint 一行就显示当前可用键，进入瞬间有反馈，调试代价低。
--
-- ── 长按怎么用 ──────────────────────────────────────────────────────────
--   <C-w>+   → resize +2 并进入 hydra（cmdline 出现 hint）
--   按住 +/-/>/< → OS key repeat 连续触发 head，连续 resize
--   按 = → equalize（继续在 hydra 内）
--   按任何非 head 键 → 退出 hydra，该键照常工作（red 语义）
--   或按 <Esc>，或等 timeout
--
-- 任何 normal-mode buffer 内（编辑窗、edgy dock buffer、snacks picker
-- list pane）都能进 hydra——只要 `<C-w>+head` 没被该 buffer 拦截，进入
-- 后 head 在当前窗口生效。
--
-- ── 后续要加新 hydra 的位置 ─────────────────────────────────────────────
-- 直接在下面 config 里多 New 一个 Hydra({...})。本文件是项目的 hydra
-- 总册——sticky chord 都集中在这里，不要散到各插件 spec 里。

return {
	"nvimtools/hydra.nvim",
	event = "VeryLazy",
	config = function()
		local Hydra = require("hydra")

		Hydra({
			name = "Window Resize",
			mode = "n",
			body = "<C-w>",
			config = {
				timeout = 1500,
			},
			heads = {
				{
					"+",
					function()
						vim.cmd("resize +2")
					end,
					{ desc = "Height +" },
				},
				{
					"-",
					function()
						vim.cmd("resize -2")
					end,
					{ desc = "Height -" },
				},
				{
					">",
					function()
						vim.cmd("vertical resize +2")
					end,
					{ desc = "Width +" },
				},
				-- "<" 在 keymap LHS 里要写成 <lt>，否则解析器认为是 <key> notation 起始
				{
					"<lt>",
					function()
						vim.cmd("vertical resize -2")
					end,
					{ desc = "Width -" },
				},
				{
					"=",
					function()
						vim.cmd("wincmd =")
					end,
					{ desc = "Equalize" },
				},
				{ "<Esc>", nil, { exit = true, desc = "Exit" } },
			},
		})
	end,
}
