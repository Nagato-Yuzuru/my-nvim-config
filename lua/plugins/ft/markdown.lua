return {
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown" },
		opts = {}, -- 先默认
		keys = {
			{
				"<localleader>l",
				function()
					require("render-markdown").toggle()
				end,
				desc = "Toggle markdown render",
			},
			{
				"<localleader>r",
				function()
					require("render-markdown").enable()
				end,
				desc = "Render markdown",
			},
			{
				"<localleader>R",
				function()
					require("render-markdown").disable()
				end,
				desc = "Disable render",
			},
		},
	},

	{
		"toppair/peek.nvim",
		ft = "markdown",
		build = "deno task --quiet build:fast",
		opts = {},
		keys = {
			{
				"<localleader>p",
				function()
					require("peek").open()
				end,
				desc = "Markdown Preview Open",
			},
			{
				"<localleader>P",
				function()
					require("peek").close()
				end,
				desc = "Markdown Preview Close",
			},
		},
	},
}
