-- Firenvim: 在浏览器 textarea 里跑真 nvim。
-- CLI 启动 nvim 时本插件保持 lazy；只有 Firenvim 拉起 nvim（vim.g.started_by_firenvim=1）
-- 才会加载，避免污染日常启动路径。
return {
	"glacambre/firenvim",
	lazy = not vim.g.started_by_firenvim,
	build = function()
		vim.fn["firenvim#install"](0)
	end,
	init = function()
		vim.g.firenvim_config = {
			globalSettings = { alt = "all" },
			localSettings = {
				[".*"] = {
					cmdline = "neovim",
					content = "text",
					priority = 0,
					selector = "textarea, div[role='textbox']",
					takeover = "never",
				},
			},
		}
	end,
}
