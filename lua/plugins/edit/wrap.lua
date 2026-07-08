-- Surround / Unwrap 三键位（.ideavimrc Generate 节的 gt/gT/gu 镜像）统一在
-- 此文件：<leader>gt/gT 包裹模板菜单 + <leader>gu 剥壳。引擎（模板表 +
-- 选区捕获 + snippet 展开）在 lua/tools/wrap.lua。
return {
	-- <leader>gt / <leader>gT：JetBrains SurroundWith / SurroundWithLiveTemplate。
	-- 菜单 UI 就是 snacks 的 ui_select（plugins/ui/snacks.lua），借它的 spec 挂
	-- 键位（lazy 按名合并 spec），键位归属和功能归属一致，core/keymaps.lua 只留
	-- 系统/窗口级键位。IDE 侧两个键是两个菜单；这里模板是一张表，两键同一 picker。
	-- 模式用 x 而非 v：展开后 select mode 里打字要落进 snippet 占位符，不能被映射截走。
	{
		"folke/snacks.nvim",
		keys = {
			{
				"<leader>gt",
				function() require("tools.wrap").pick() end,
				mode = { "x", "n" },
				desc = "Surround with template",
			},
			{
				"<leader>gT",
				function() require("tools.wrap").pick() end,
				mode = { "x", "n" },
				desc = "Surround with template",
			},
		},
	},

	-- <leader>gu：JetBrains Unwrap。删掉包裹的 if/for/try/tag 等构造并把内容左移。
	-- 入口是 tools/wrap.lua 的 M.unwrap()：光标在块内任意位置都行（treesitter
	-- 祖先链先定位到包裹行，对齐 IDE 语义），IDE 的"选层弹窗"用光标深度代替
	-- （光标在越内层就剥越内层）。
	--
	-- deleft 是 matchit 扩展匹配 + 缩进回退实现（非 treesitter）：多分支
	-- （if/elsif/else/end）一次全剥、默认保留所有分支体（g:deleft_remove_strategy
	-- 可改成只留光标分支）。删完只左移不重排格式，Go/Lua 的格式差异由
	-- format-on-save（conform）兜底。
	{
		"AndrewRadev/deleft.vim",
		-- matchup（plugins/edit/enhance.lua）自带 matchit 兼容层（g:loaded_matchit
		-- + b:match_words）。显式依赖保证 deleft 装载时它已就位，否则 deleft 会
		-- 自己 packadd 内建 matchit，和 matchup 重复。
		dependencies = { "andymass/vim-matchup" },
		init = function()
			-- 不占用默认 dh（X 的同义键，肌肉记忆里是删字符）；统一走 <leader>gu
			vim.g.deleft_mapping = ""
		end,
		cmd = "Deleft",
		keys = {
			{
				"<leader>gu",
				function() require("tools.wrap").unwrap() end,
				desc = "Unwrap surrounding block (deleft)",
			},
		},
	},
}
