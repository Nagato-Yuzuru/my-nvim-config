---
--- Created by yuzuru.
---
return {
	{
		"mfussenegger/nvim-lint",
		event = "VeryLazy",
		config = function()
			local lint = require("lint")

			lint.linters_by_ft = require("tools.mason_ensure").get_linters_by_ft()

			vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
				callback = function() lint.try_lint() end,
			})

			vim.schedule(lint.try_lint)
		end,
	},
}
