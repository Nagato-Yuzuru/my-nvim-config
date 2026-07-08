return {
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		opts = {
			plugins = { spelling = true },
			win = {
				border = "rounded",
				padding = { 1, 2 },
			},
			filter = function(mapping) return mapping.desc ~= nil end,
		},
		config = function(_, opts)
			local wk = require("which-key")
			wk.setup(opts)
			-- which-key v3 group 不支持 `ft` 字段，要 ft scope 走 `cond` 函数
			-- （schema 见 which-key/lua/which-key/mappings.lua: M.fields）。
			local function ft_in(...)
				local fts = { ... }
				return function() return vim.tbl_contains(fts, vim.bo.filetype) end
			end
			wk.add({
				{ "<leader>n", group = "Navigation" },
				{ "<leader>s", group = "Search" },
				{ "<leader>r", group = "Refactor" },
				{ "<leader>v", group = "Views" },
				-- <leader>g holds only the surround/unwrap trio（gt/gT/gu，镜像自 IDE
				-- Generate 菜单里的 SurroundWith/Unwrap）；代码 GENERATION 仍走 <leader>ca
				-- (vim.lsp.buf.code_action)——完整的 asymmetry 说明见 .ideavimrc Generate 节。
				{ "<leader>g", group = "Surround / Unwrap" },
				{ "<leader>d", group = "Debug" },
				{ "<leader>t", group = "Test" },
				{ "<leader>o", group = "Overseer / Run" },
				{ "<leader>f", group = "Format" },
				{ "<leader>m", group = "Mark" },
				{ "<leader>c", group = "Code" },
				{ "<leader><leader>", group = "Motion (Flash)" },
				{ "gp", group = "Preview (LSP)" },
				{ "<C-x>", group = "Window / Buffer" },
				{ "<localleader>g", group = "Git" },
				{ "<localleader>d", group = "Diff (mini.diff)" },
				{ "<localleader>l", group = "LeetCode" },
				-- Obsidian 只在 markdown 这边有意义；不限 ft 的话 which-key 会在每个 buffer
				-- 都把 ,o 提示成 "Obsidian"，加上 v3 的 icon 自动派生，落到 scheme/racket
				-- 里就会出现 "Obsidian + lisp 图标" 这种迷惑组合。
				{ "<localleader>o", group = "Obsidian", cond = ft_in("markdown", "obsidian") },
				{ "<localleader>m", group = "Markdown" },
				{ "<localleader>c", group = "Crates (Cargo.toml)" },
				{ "<localleader>t", group = "Typst" },
				-- Scheme 系组名（<localleader>c / <localleader>p）以 buffer-local 形式在
				-- lua/plugins/lang/scheme.lua 的 config() 里注册，不在这里重复声明。
			})
		end,
	},
}
