---
--- image.nvim — 在终端里渲染图片
--- 依赖: WezTerm/Kitty/Ghostty 等支持 kitty graphics 协议的终端
---        系统装 imagemagick (`brew install imagemagick`)，提供 `magick` CLI
--- 集成: markdown 文件内嵌图片自动渲染；leetcode.nvim 直接调 from_url
---

return {
	"3rd/image.nvim",
	lazy = true,
	ft = { "markdown", "vimwiki", "norg" },
	cmd = { "Leet" }, -- leetcode 入口也要保证 setup 已跑过
	opts = {
		backend = "kitty",
		processor = "magick_cli",
		max_width = 100,
		max_height = 30,
		max_width_window_percentage = nil,
		max_height_window_percentage = 50,
		tmux_show_only_in_active_window = true,
		window_overlap_clear_enabled = true, -- 浮窗/补全弹出时自动清掉重叠的图片
		window_overlap_clear_ft_ignore = {
			"cmp_menu",
			"cmp_docs",
			"snacks_picker_list",
			"snacks_picker_preview",
			"noice",
			"scrollview",
			"scrollview_sign",
		},
		editor_only_render_when_focused = false,
		integrations = {
			markdown = {
				enabled = true,
				clear_in_insert_mode = false,
				download_remote_images = true, -- 渲染远程 URL 图片
				only_render_image_at_cursor = false,
				filetypes = { "markdown", "vimwiki", "quarto" },
			},
			neorg = {
				enabled = false,
			},
			html = { enabled = false },
			css = { enabled = false },
		},
	},
}
