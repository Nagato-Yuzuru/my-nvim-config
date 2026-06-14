---
--- videre.nvim — 把 JSON/YAML/TOML 渲染成可交互节点图（JSON Crack 风格）
--- 入口: 在数据 buffer 内 :Videre（或 <leader>vj）打开图视图
--- 图内键位（buffer-local，不与全局键冲突，全部可经 opts.keymaps 重绑）:
---   导航 H 回父 / L 顺引用 / J·K 同列上下 / R 设为根
---   编辑 C 改键 / V 改值 / D 删 / A 增 / T 切换数组↔对象
---   其它 E 展开折叠 / g? 帮助 / q 退出
--- parity: nvim-only —— JetBrains 无对应 Action，按「视图/工具」单边存在惯例
---         不镜像到 .ideavimrc（同 <leader>s* 搜索）。
---
return {
	"Owen-Dechow/videre.nvim",
	cmd = "Videre",
	dependencies = {
		"Owen-Dechow/graph_view_yaml_parser", -- YAML
		"Owen-Dechow/graph_view_toml_parser", -- TOML
		-- XML 名义上 optional，但 videre.langs.xml 缺 xml2lua 时 return nil，而
		-- langs/init.lua 的 add_lang 用 `result ~= nil` 判空——Lua 里 chunk 返回
		-- nil 会让 require 返回 true(boolean)，于是 result[1] 索引布尔值崩溃，
		-- 导致 :Videre 整个挂掉。故此依赖实为必需，直到上游修掉 add_lang。
		"a-usr/xml2lua.nvim",
	},
	keys = {
		{ "<leader>vj", "<cmd>Videre<cr>", desc = "Videre: graph view" },
	},
	opts = {
		box_style = "sharp",
	},
}
