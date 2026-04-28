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
				{ "<localleader>o", group = "Obsidian" },
				{ "<localleader>m", group = "Markdown" },
				{ "<localleader>c", group = "Crates (Cargo.toml)" },
				{ "<localleader>t", group = "Typst" },
			})
		end,
	},
}
