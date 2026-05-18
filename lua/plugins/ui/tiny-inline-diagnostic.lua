-- IDEA / VS Code Error Lens 风的诊断行内气泡。
--
-- 接管 vim.diagnostic 的 virtual_text + virtual_lines 显示职责：把短消息渲染
-- 成行尾带颜色背景的圆角胶囊，光标当前行展开全部诊断（多条 / 多行）。原生
-- virtual_text 在 lua/core/diagnostic.lua 里已经关掉——两者并存会重叠。
--
-- 仍保留：underline (字符波浪线) / signs (侧栏图标) / float (浮窗) / 跳转键。
-- tiny-inline 只替显示器，不接管诊断源 / 不接管 ]d 跳转。

return {
	{
		"rachartier/tiny-inline-diagnostic.nvim",
		event = "VeryLazy",
		-- priority 高一点：在其它 UI 插件之前抢先 hook diagnostic 显示
		priority = 1000,
		opts = {
			preset = "modern", -- modern | classic | minimal | powerline | ghost | simple | nonerdfont | amongus
			transparent_bg = false,
			transparent_cursorline = false,
			hi = {
				-- 沿用 Diagnostic* 系列高亮，跟随 colorscheme 切换自动重算
				error = "DiagnosticError",
				warn = "DiagnosticWarn",
				info = "DiagnosticInfo",
				hint = "DiagnosticHint",
				arrow = "NonText",
				background = "CursorLine",
				mixing_color = "None",
			},
			options = {
				-- 行尾胶囊里附带来源标签（gopls / golangci-lint / tsc / eslint…），
				-- 同一行有多源时尤其重要——单源时省略避免噪音。
				show_source = {
					enabled = true,
					if_many = true,
				},
				-- 把诊断里的 `back-ticked` 高亮成 inline code
				use_icons_from_diagnostic = false,
				-- 远处行只显示首条诊断的截断；光标当前行展开全部。
				multilines = {
					enabled = true,
					always_show = false, -- 仅当前行
				},
				-- 光标行展开所有诊断（替代 virtual_lines.current_line 的角色）
				show_all_diags_on_cursorline = true,
				-- 插入模式不渲染——和我们 core/diagnostic.lua 的 update_in_insert=false 一致
				enable_on_insert = false,
				-- 选区时也不渲染（避免和高亮的视觉冲突）
				enable_on_select = false,
				overflow = {
					-- 文本超出窗口宽度时换行展示（wrap），而不是被截断（none）
					mode = "wrap",
				},
				-- break_line 让长消息按句号 / 逗号自然换行
				break_line = {
					enabled = false,
					after = 30,
				},
				virt_texts = {
					priority = 2048,
				},
				-- 哪些 severity 显示——这里全显示，按 severity_sort 排序
				severity = {
					vim.diagnostic.severity.ERROR,
					vim.diagnostic.severity.WARN,
					vim.diagnostic.severity.INFO,
					vim.diagnostic.severity.HINT,
				},
			},
			-- 禁用列表：某些 buffer 里不渲染（dashboards / 命令窗等）
			disabled_ft = { "lazy", "mason", "TelescopePrompt", "snacks_dashboard" },
		},
	},
}
