return {
	{
		"jmbuhr/otter.nvim",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		cmd = { "OtterActivate", "OtterDeactivate" },
		opts = {
			lsp = {
				diagnostic_update_events = { "BufWritePost", "InsertLeave", "TextChanged" },
			},
			buffers = {
				set_filetype = true,
				write_to_disk = false,
			},
			handle_leading_whitespace = true,
		},
		config = function(_, opts)
			require("otter").setup(opts)
			vim.api.nvim_create_user_command("OtterActivate", function()
				require("otter").activate()
			end, { desc = "Otter: activate LSP in injected regions" })
			vim.api.nvim_create_user_command("OtterDeactivate", function()
				require("otter").deactivate()
			end, { desc = "Otter: deactivate" })
		end,
	},
}
