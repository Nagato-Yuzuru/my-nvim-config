return {
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		opts = {
			plugins = { spelling = true },
			win = {
				border = "rounded",
				padding = { 1, 2 },
				-- 如果你想要透明度，which-key v3 把窗口局部选项放到 wo 里：
				-- wo = { winblend = 10 },
			},
			filter = function(mapping)
				return mapping.desc ~= nil
			end,
		},
		config = function(_, opts)
			local wk = require("which-key")
			wk.setup(opts)
			-- which-key v3 group 不支持 `ft` 字段，要 ft scope 走 `cond` 函数
			-- （schema 见 which-key/lua/which-key/mappings.lua: M.fields）。
			local function ft_in(...)
				local fts = { ... }
				return function()
					return vim.tbl_contains(fts, vim.bo.filetype)
				end
			end
			wk.add({
				{ "<leader>n", group = "Navigation" },
				{ "<leader>s", group = "Search" },
				{ "<leader>r", group = "Refactor" },
				{ "<leader>v", group = "Views" },
				{ "<leader>g", group = "Generate" },
				{ "<leader>d", group = "Debug" },
				{ "<leader>t", group = "Test" },
				{ "<leader>o", group = "Overseer / Run" },
				{ "<leader>f", group = "Format" },
				{ "<leader>m", group = "Mark" },
				{ "<leader>c", group = "Code" },
				{ "<leader><leader>", group = "Motion (Flash)" },
				{ "<C-x>", group = "Window / Buffer" },
				{ "<localleader>g", group = "Git" },
				{ "<localleader>l", group = "LeetCode" },
				-- Obsidian 只在 markdown 这边有意义；不限 ft 的话 which-key 会在每个 buffer
				-- 都把 ,o 提示成 "Obsidian"，加上 v3 的 icon 自动派生，落到 scheme/racket
				-- 里就会出现 "Obsidian + lisp 图标" 这种迷惑组合。
				{ "<localleader>o", group = "Obsidian", cond = ft_in("markdown", "obsidian") },
				{ "<localleader>m", group = "Markdown" },
				{ "<localleader>c", group = "Crates (Cargo.toml)" },
				{ "<localleader>t", group = "Typst" },
				-- Scheme 系（lua/plugins/lang/scheme.lua）：Conjure REPL eval + nvim-paredit
				-- 结构化编辑。按键由插件自身用 desc 注册到 buffer，which-key 只需提供
				-- 组名 + cond 让它们在对应 buffer 出现并不污染其它 ft。
				-- 注意：和 "Crates (Cargo.toml)" 在 ,c 处共存——后者没加 cond 是历史原因
				-- （label 已说明 Cargo.toml 专用），duplicate 仅是 informational warning。
				{ "<localleader>c", group = "Conjure (Eval / REPL)", cond = ft_in("scheme", "racket", "lisp") },
				{ "<localleader>p", group = "Paredit (struct edit)", cond = ft_in("scheme", "racket", "lisp") },
			})
		end,
	},
}
