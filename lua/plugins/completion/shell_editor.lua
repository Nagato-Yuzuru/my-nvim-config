
return {
	-- cmp-zsh: 在 edit-command-line（zsh filetype）里提供 zsh 补全候选
	-- 注意：fzf-tab 的 UI 无法在 nvim 内还原，但候选列表来源相同
	{
		"tamago324/cmp-zsh",
		ft = { "zsh" },
		dependencies = {
			"saghen/blink.cmp",
			"saghen/blink.compat",
			"nvim-lua/plenary.nvim",
		},
		init = function()
			vim.env.NVIM_ZSH_COMPLETION = "1"

			-- edit-command-line 产生的临时文件路径（macOS + Linux）
			vim.filetype.add({
				pattern = {
					["^/tmp/zsh.*"] = "zsh",
					["^/private/var/folders/.*"] = "zsh",
					["^/var/folders/.*"] = "zsh",
				},
			})
		end,
		config = function()
			require("cmp_zsh").setup({
				zshrc = true,
				filetypes = { "zsh" },
			})
		end,
	},

	-- 把 zsh source 注入 blink.cmp（lazy.nvim 会 deep-merge 这个 spec）
	{
		"saghen/blink.cmp",
		optional = true,
		opts = {
			sources = {
				-- 只在 zsh filetype 时加入 zsh source；其余 filetype 不受影响
				default = function()
					local defaults = { "lsp", "path", "buffer", "snippets" }
					if vim.bo.filetype == "zsh" then
						table.insert(defaults, 1, "zsh")
					end
					return defaults
				end,
				providers = {
					zsh = {
						name = "zsh",
						module = "blink.compat.source",
						score_offset = 3,
						-- cmp-zsh 把 zsh 描述放在 documentation（侧边弹窗）；
						-- blink.cmp 菜单的 label_description 列读的是 labelDetails.description，
						-- 因此需要把描述搬到这里才能内联显示
						transform_items = function(_, items)
							for _, item in ipairs(items) do
								local doc = item.documentation
								if doc ~= nil then
									local desc = type(doc) == "table" and doc.value or doc
									if desc and desc ~= "" then
										item.labelDetails = item.labelDetails or {}
										item.labelDetails.description = desc
									end
								end
							end
							return items
						end,
					},
				},
			},
		},
	},
}
