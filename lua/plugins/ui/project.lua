---
--- Created by colas.
--- 项目根目录自动感知：打开不同项目文件时静默切换 cwd，
--- 使 LSP / grep 等始终以正确的项目根为基准。
---
return {
	{
		"ahmedkhalf/project.nvim",
		event = "VeryLazy",
		config = function()
			require("project_nvim").setup({
				detection_methods = { "lsp", "pattern" },
				patterns = { ".git", "go.mod", "pyproject.toml", "Makefile" },
				silent_chdir = true, -- 静默切换，无弹窗
				show_hidden = false,
			})
		end,
	},
}
