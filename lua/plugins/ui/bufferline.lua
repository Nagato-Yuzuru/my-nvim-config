return {
	{
		"akinsho/bufferline.nvim",
		event = "VeryLazy",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			{ "echasnovski/mini.bufremove", version = false }, -- 更靠谱的关缓冲
		},
		opts = {
			options = {
				diagnostics = "nvim_lsp",
				offsets = {
					{ filetype = "snacks_layout_box", text = "Explorer", highlight = "Directory", separator = true },
				},
				separator_style = "slant",
				-- 关闭按钮行为交给 mini.bufremove
				close_command = function(n)
					require("mini.bufremove").delete(n, false)
				end,
				right_mouse_command = function(n)
					require("mini.bufremove").delete(n, false)
				end,
			},
		},
		keys = {
			{ "<C-x>n", "<cmd>BufferLineCycleNext<CR>", desc = "Next buffer" },
			{ "<C-x>p", "<cmd>BufferLineCyclePrev<CR>", desc = "Prev buffer" },

			-- 选择跳转 / 选择关闭
			{ "<C-x>o", "<cmd>BufferLinePick<CR>", desc = "Pick buffer" },
			{ "<C-x>k", "<cmd>BufferLinePickClose<CR>", desc = "Pick & close buffer" },
			{
				"<C-x>K",
				function()
					require("mini.bufremove").delete(0, true)
				end,
				desc = "Force close current buffer",
			},
			{ "<C-x>,", "<cmd>BufferLineMovePrev<CR>", desc = "Move buffer left" },
			{ "<C-x>.", "<cmd>BufferLineMoveNext<CR>", desc = "Move buffer right" },
			{
				"<C-x>0",
				function()
					local ok, br = pcall(require, "mini.bufremove")
					if ok then
						br.delete(0, false)
					else
						vim.cmd("bdelete")
					end
				end,
				desc = "Close current buffer",
			},
			{ "<C-x>)", "<cmd>BufferLineCloseOthers<CR>", desc = "Close other buffers" },
			{ "<C-x>[", "<cmd>BufferLineCloseLeft<CR>", desc = "Close buffers to the left" },
			{ "<C-x>]", "<cmd>BufferLineCloseRight<CR>", desc = "Close buffers to the right" },
		},
	},
}
