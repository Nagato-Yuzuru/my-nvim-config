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

			-- Find the nearest ancestor directory containing `filename`.
			local function find_root(filename)
				local buf_dir = vim.fn.expand("%:p:h")
				local found = vim.fs.find(filename, { path = buf_dir, upward = true })[1]
				return found and vim.fn.fnamemodify(found, ":h") or nil
			end

			-- Per-filetype root markers for monorepo-friendly cwd.
			local root_markers = {
				go = "go.mod",
			}

			vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
				callback = function()
					local ft = vim.bo.filetype
					local marker = root_markers[ft]
					local cwd = marker and find_root(marker) or nil
					lint.try_lint(nil, { cwd = cwd })
				end,
			})

			vim.schedule(function() lint.try_lint() end)
		end,
	},
}
