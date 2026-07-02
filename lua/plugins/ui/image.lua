---
--- image.nvim — 仅作为 leetcode.nvim 的「图像库后端」使用。
--- leetcode 硬编码 `require("image").from_url(...)` + `img:render{}`
--- (见 leetcode.nvim/lua/leetcode-ui/split/description.lua),snacks.image
--- 没有对应 API,顶替不了,所以这个插件为它保留。
---
--- Markdown / 文档内联图片、数学、mermaid、SVG 一律交给 snacks.image
--- (lua/plugins/ui/snacks.lua 的 `image` 模块)。分工原因:snacks 判转换
--- 成功只看退出码不看 stderr,SVG 缺字体只告警不中断;而 image.nvim 的
--- magick_cli 会因此报错。
---
--- 因此这里 **不再挂 markdown/vimwiki/norg 的 ft 触发,并关掉所有 filetype
--- 集成** —— 否则会和 snacks.image 在同一 buffer 抢渲染(重影/打架)。
--- 只随 `:Leet` 加载(它同时是 leetcode.nvim 的 dependency)。
--- 依赖: Ghostty/Kitty 等 kitty graphics 终端 + 系统 imagemagick。
---

return {
	"3rd/image.nvim",
	lazy = true,
	cmd = { "Leet" }, -- 仅随 leetcode 加载;image.setup 在此跑一次
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
		-- 全部关闭:文档类渲染归 snacks.image。image.nvim 只作 leetcode 的
		-- 库后端(直接 from_url),不做任何 filetype 集成,避免双渲染冲突。
		integrations = {
			markdown = { enabled = false },
			neorg = { enabled = false },
			html = { enabled = false },
			css = { enabled = false },
		},
	},
}
