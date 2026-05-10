-- aaronik/treewalker.nvim — AST 兄弟 / 父子节点导航
--
-- 填补 `[`/`]` textobject 跳转和 matchup `%` 都覆盖不到的空白：
-- JSON/YAML/TOML/XML/HTML/Markdown 这类**没有 function/loop/class/conditional
-- 概念**的结构化文件，用同级兄弟跳转才是正确导航语义。代码里也有用——
-- Lua 表字段、struct 字段间跳转。
--
-- 强依赖 treesitter（用 `vim.treesitter` API）：没装对应 parser 的 buffer 里
-- 静默失效。日常 langs 已通过 nvim-treesitter `ensure_installed` 覆盖。
--
-- 键位归属：`<leader>n*` (Navigation extras) 命名空间下的 `<leader>nh/j/k/l`，
-- 用 hydra 包成 sticky 模式。绑定**全部**在 `lua/plugins/ui/hydra.lua` 里
-- 集中定义——本文件只负责插件 spec 和外观。treewalker 默认不创建任何
-- keymap，无需 disable。
return {
	"aaronik/treewalker.nvim",
	event = "VeryLazy",
	opts = {
		highlight = true,
		highlight_duration = 250,
		highlight_group = "ColorColumn",
	},
}
