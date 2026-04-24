-- Sticky header showing the enclosing function/class/if the cursor is in.
-- Complements the JetBrains breadcrumb bar on the IdeaVim side.
return {
	"nvim-treesitter/nvim-treesitter-context",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	event = "VeryLazy",
	opts = {
		max_lines = 3, -- cap header height so it doesn't swallow the buffer
		min_window_height = 20, -- disable on short splits
		multiline_threshold = 1, -- collapse multi-line node headers to one line
		trim_scope = "outer", -- when truncated, drop outermost (keep innermost context visible)
		mode = "cursor", -- update as cursor moves, not only on scroll
		line_numbers = true,
	},
}
