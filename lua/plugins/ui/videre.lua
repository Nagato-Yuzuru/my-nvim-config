---
--- videre.nvim — 把 JSON/YAML/TOML 渲染成可交互节点图（JSON Crack 风格）
--- 入口: 在 json/yaml/toml buffer 内 :Videre，或 buffer-local <localleader>v 打开图视图
--- 图内键位（buffer-local，不与全局键冲突，全部可经 opts.keymaps 重绑）:
---   导航 H 回父 / L 顺引用 / J·K 同列上下 / R 设为根
---   编辑 C 改键 / V 改值 / D 删 / A 增 / T 切换数组↔对象
---   其它 E 展开折叠 / g? 帮助 / q 退出
--- parity: nvim-only —— JetBrains 无对应 Action；键位归 <localleader>v（文件限定
---         查看器约定，同 csvview/Obsidian/LeetCode），不镜像到 .ideavimrc。
---
return {
	"Owen-Dechow/videre.nvim",
	cmd = "Videre",
	dependencies = {
		"Owen-Dechow/graph_view_yaml_parser", -- YAML
		"Owen-Dechow/graph_view_toml_parser", -- TOML
		-- videre.langs.xml 顶层 require("xml2lua")，缺了它 add_lang 的 pcall 会
		-- 静默跳过 XML（不再像旧版那样崩掉 :Videre）——显式声明依赖，别靠静默
		-- 降级发现少了 XML 支持。
		"a-usr/xml2lua.nvim",
	},
	-- 文件限定查看器：键位走 localleader（同 Obsidian/LeetCode/Conjure 约定），
	-- 在 json/yaml/toml 上 buffer-local 绑 <localleader>v。用 init 而非 config，
	-- 这样无需加载 videre 即可挂键；按下时 :Videre 经 cmd 懒加载再开。
	init = function()
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("UserVidereKeys", { clear = true }),
			pattern = { "json", "jsonc", "yaml", "toml" },
			callback = function(ev)
				vim.keymap.set(
					"n",
					"<localleader>v",
					"<cmd>Videre<cr>",
					{ buffer = ev.buf, desc = "Videre: graph view" }
				)
			end,
		})
	end,
	opts = {
		box_style = "sharp",
	},
}
