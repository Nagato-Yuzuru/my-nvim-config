---
--- Created by yuzuru.
--- DateTime: 2025/12/9 12:30
---

return {
	{
		"tamago324/cmp-zsh",
		ft = { "zsh" },
		event = "VeryLazy",
		dependencies = {
			"saghen/blink.cmp",
			"saghen/blink.compat",
			"nvim-lua/plenary.nvim",
		},
		init = function()
			vim.env.NVIM_ZSH_COMPLETION = "1"
			vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
				group = vim.api.nvim_create_augroup("zsh_edit_proxy", { clear = true }),
				pattern = { "/tmp/zsh*", "/private/var/folders/*", "/var/folders/*" },
				callback = function()
					vim.bo.filetype = "zsh"
				end,
			})
		end,
		config = function()
			require("cmp_zsh").setup({
				zshrc = true,
				filetypes = { "zsh" },
			})
		end,
		opts = {
			sources = {
				default = { "lsp", "path", "snippets", "buffer", "zsh" },
				providers = {
					zsh = {
						name = "zsh",
						module = "blink.compat.source",
						score_offset = 3,
					},
				},
			},
		},
	},
}
