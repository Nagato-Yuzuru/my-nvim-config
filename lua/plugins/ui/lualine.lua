return {
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		cond = function() return not vim.g.started_by_firenvim end,
		opts = {
			options = {
				theme = "tokyonight",
				component_separators = "",
				section_separators = { left = "", right = "" },
				globalstatus = true,
				disabled_filetypes = {
					statusline = { "snacks_layout_box" },
				},
			},
			sections = {
				lualine_a = { {
					"mode",
					fmt = function(s) return s:sub(1, 3) end,
				} },
				lualine_b = {
					{ "branch", icon = "" },
					{
						"diff",
						symbols = { added = "+", modified = "@", removed = "-" },
					},
				},
				lualine_c = {
					{
						"diagnostics",
						symbols = { error = " ", warn = " ", info = " ", hint = " " },
					},
				},
				lualine_x = {
					(function()
						-- 录制中显示寄存器名，录完后显示内容（截断）。
						-- last_reg 由下面 component 函数在 reg_recording() ~= "" 时
						-- 写入；不要再绑 RecordingLeave —— 该事件触发时
						-- reg_recording() 已经返回 ""，会反向把 last_reg 抹掉。
						local last_reg = nil
						return {
							function()
								local reg = vim.fn.reg_recording()
								if reg ~= "" then
									last_reg = reg
									return "󰑋 recording @" .. reg .. "…"
								end
								if last_reg then
									local content = vim.fn.getreg(last_reg)
									if content ~= "" then
										content = content:gsub("\n", "↵"):sub(1, 30)
										return "󰑋 @" .. last_reg .. " " .. content
									end
								end
								return ""
							end,
							color = { fg = "#ff966c" },
						}
					end)(),
					{
						-- 当前 buffer 的 LSP server
						function()
							local clients = vim.lsp.get_clients({ bufnr = 0 })
							if #clients == 0 then
								return ""
							end
							local names = {}
							for _, c in ipairs(clients) do
								names[#names + 1] = c.name
							end
							return " " .. table.concat(names, ", ")
						end,
					},
				},
				lualine_y = { "filetype" },
				lualine_z = { "%l:%c" },
			},
		},
	},
}
