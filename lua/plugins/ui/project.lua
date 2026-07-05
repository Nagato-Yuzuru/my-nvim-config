---
--- 项目根目录自动感知：打开不同项目文件时静默切换 cwd，
--- 使 LSP / grep 等始终以正确的项目根为基准。
---
return {
	{
		"DrKJeff16/project.nvim",
		-- setup() 只给"未来"的 BufEnter/LspAttach 注册 autocmd，不会回溯检测已打开的
		-- buffer；VeryLazy 在第一个文件的 BufEnter 之后才触发，会导致本次会话的
		-- 第一个 buffer 一直等不到 project-root cwd，直到第二次 buffer 事件。
		lazy = false,
		config = function()
			require("project").setup({
				patterns = { ".git", "go.mod", "pyproject.toml", "Makefile" },
				silent_chdir = true,
			})
		end,
	},
}
