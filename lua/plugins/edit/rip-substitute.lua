-- nvim-rip-substitute: 当前 buffer 的 :s 加强版（PCRE2 + 增量预览）。
-- 仅作用于当前 buffer —— 工作区级多文件替换走 <leader>sR（grug-far，见
-- lua/plugins/edit/grug-far.lua）。
--
-- 入口策略：和 vim 原生 :s 完全独立，两个口子并存：
--   :s/foo/bar/g          → vim 原生，vim 正则，inccommand=split 提供预览
--   <leader>sr            → 弹 popup，PCRE2 语法，作用于当前 buffer
--
-- 不 alias :s、不 cabbrev、不 hijack 命令行 —— 想用 PCRE2 就按 <leader>sr，
-- 其他场景 :s 照旧。两套语法各走各的。
--
-- Namespace 选择：放在 <leader>s* (search/substitute) 而非 README 默认的
-- <leader>rs —— 因为 <leader>r* 已被 LSP refactor 占用（见 lua/core/lsp.lua
-- LspAttach 与 .ideavimrc 的 <leader>r* refactor 段）。
--
-- 依赖：ripgrep（已通过 mason 之外的系统安装；brew 默认带 pcre2）。

return {
	{
		"chrisgrieser/nvim-rip-substitute",
		cmd = "RipSubstitute",
		keys = {
			{
				"<leader>sr",
				function() require("rip-substitute").sub() end,
				mode = { "n", "x" },
				desc = "Substitute (rip-substitute, PCRE2)",
			},
		},
		opts = {
			popupWin = {
				title = " rip-substitute (PCRE2) ",
			},
			prefill = {
				normal = "cursorWord", -- normal 模式自动填光标下的词（已转义）
				visual = "selection", -- visual 模式自动填选区
			},
			regexOptions = {
				pcre2 = true, -- 启用 lookaround / backreference
			},
			editingBehavior = {
				-- 在 search 行键入 () 时自动在 replace 行追加 $n —— 命名捕获组场景请关。
				autoCaptureGroups = false,
			},
		},
	},
}
