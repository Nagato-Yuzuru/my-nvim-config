-- bang.nvim（Nagato-Yuzuru/bang.nvim，我们自己的插件）：把 motion / text object
-- / Visual 选区通过 shell 命令过滤后原地回写。是内建 `!` 的超集——`!` 只按整行
-- 工作，g! 保留 motion 的粒度（charwise / linewise / blockwise），命令失败时不动
-- buffer，`.` 连 shell 命令一起重复，裸 :Bang 从 `:` 历史里挑上一条重放。
-- 对应的 IdeaVim 侧说明在 .ideavimrc "9) Shell filter" 节。
--
-- 键位 g! / g!! / v_g! 由 plugin/bang.lua 自己在加载时创建（bang-config 的
-- keymaps 默认 true，且它不抢已有全局映射），本文件不重复 map。
--
-- 不能用 keys = { "g!" } 懒加载：plugin/bang.lua 的 setup_autocmds() 用
-- ModeChanged + CursorMoved 记录 blockwise Visual 的两个角和 `$` ragged 标志，
-- 这套追踪必须在按 <C-v> **之前**就挂上。挂在 g! 上等于第一次块选时追踪器还不
-- 存在，块选（尤其带 `$` 的不齐块）会静默退化。VeryLazy 是仍然安全的最晚时机。
return {
	{
		"Nagato-Yuzuru/bang.nvim",
		event = "VeryLazy",
	},
}
