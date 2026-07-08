return {
	{
		"akinsho/toggleterm.nvim",
		version = "*",
		keys = {
			{ "<C-x>`", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
		},
		opts = {
			open_mapping = [[<C-x>`]],
			shade_terminals = true,
			direction = "horizontal",
			size = function(term)
				if term.direction == "horizontal" then
					return math.floor(vim.o.lines * 0.28)
				end
				return 20
			end,
			float_opts = { border = "rounded" },
			start_in_insert = true, -- 打开就进插入模式
			persist_size = false, -- 不记住手动拖过的大小，每次按 size() 重开
			insert_mappings = true, -- 插入模式下也能用 open_mapping
			close_on_exit = true,
			shell = vim.o.shell, -- 跟随当前 shell
		},
		config = function(_, opts)
			require("toggleterm").setup(opts)
			-- 终端内常用按键：退出/切窗（像 IDE 一样顺手）
			vim.api.nvim_create_autocmd("TermOpen", {
				pattern = "term://*",
				callback = function()
					local function tmap(lhs, rhs, desc)
						vim.keymap.set("t", lhs, rhs, { buffer = 0, noremap = true, silent = true, desc = desc })
					end
					tmap("<Esc>", [[<C-\><C-n>]], "Terminal: normal mode")
					tmap("<C-h>", [[<C-\><C-n><C-w>h]], "Terminal: window left")
					tmap("<C-j>", [[<C-\><C-n><C-w>j]], "Terminal: window down")
					tmap("<C-k>", [[<C-\><C-n><C-w>k]], "Terminal: window up")
					tmap("<C-l>", [[<C-\><C-n><C-w>l]], "Terminal: window right")
				end,
			})
		end,
	},
}
