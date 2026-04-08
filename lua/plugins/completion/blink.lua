---
--- Created by yuzuru.
--- DateTime: 2025/11/4 01:30
---
return {
	{
		"saghen/blink.cmp",
		event = { "InsertEnter", "CmdlineEnter" },
		dependencies = {
			"L3MON4D3/LuaSnip",
			"rafamadriz/friendly-snippets",
			"xzbdmw/colorful-menu.nvim",
		},
		build = "cargo +nightly build --release",
		opts = {
			fuzzy = { implementation = "prefer_rust" },
			keymap = { -- 常用键位
				preset = "none",
				["<cr>"] = { "accept", "fallback" },
				["<Tab>"] = { "accept", "fallback" }, -- 等价: select=true 再确认
				["<A-/>"] = { "show", "show_documentation" }, -- 触发补全/文档
				--["<C-Esc>"] = { "hide" },                       -- 取消
				["<C-p>"] = { "select_prev", "fallback" }, -- 上一个
				["<C-n>"] = { "select_next", "fallback" }, -- 下一个
				["<C-b>"] = { "scroll_documentation_up", "fallback" },
				["<C-f>"] = { "scroll_documentation_down", "fallback" },
				["<S-Tab>"] = { "select_prev", "fallback" },
			},
			appearance = { nerd_font_variant = "mono" },
			sources = {
				default = { "lsp", "path", "buffer", "snippets" },
			},
			completion = {
				menu = {
					border = "rounded",
					winblend = 0,
				},
				documentation = {
					auto_show = true,
					window = { border = "rounded", winblend = 0 },
				},
			},
			signature = { -- 插入时签名提示（与 <A-P> 互补）
				enabled = true,
				window = { border = "rounded", winblend = 0 },
			},
			snippets = { preset = "luasnip" },
			cmdline = {
				keymap = {
					preset = "none",
					["<C-n>"]   = { "select_next", "fallback" },
					["<C-p>"]   = { "select_prev", "fallback" },
					["<Tab>"]   = { "show", "select_next", "fallback" },
					["<S-Tab>"] = { "select_prev", "fallback" },
					["<cr>"]    = { "fallback" },
					-- 行尾有 ghost text 则 accept，否则前进一字
					["<C-f>"] = { function(cmp)
						if vim.fn.getcmdpos() > #vim.fn.getcmdline() then
							return cmp.accept()
						end
						vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Right>", true, true, true), "cn", false)
						return true
					end },
				},
				completion = {
					-- 只在输入 : 命令时自动显示菜单；/ ? 搜索仍按原生行为
					menu = {
						auto_show = function()
							return vim.fn.getcmdtype() == ":"
						end,
					},
					ghost_text = { enabled = true }, -- 装了 noice 时会有"灰色建议"效果
				},
				-- 源的控制（一般默认就行；需要的话可增加 min_keyword_length 等）
				-- sources = {
				--   default = { "cmdline", "path" }, -- :cmd 时
				--   search  = { "buffer" },          -- / ? 时
				-- },
			},
		},
		config = function(_, opts)
			-- 载入片段
			require("luasnip.loaders.from_vscode").lazy_load()
			require("blink.cmp").setup(opts)

			-- cmdline Emacs/shell 风格导航
			local map = vim.keymap.set
			map("c", "<C-a>", "<Home>",   { noremap = true })
			map("c", "<C-b>", "<Left>",   { noremap = true })
			map("c", "<M-b>", "<S-Left>", { noremap = true })
			map("c", "<M-f>", "<S-Right>",{ noremap = true })
			map("c", "<C-k>", function()
				local col = vim.fn.getcmdpos()
				vim.fn.setcmdline(vim.fn.getcmdline():sub(1, col - 1))
			end, { noremap = true })

			-- if pcall(require, "lspkind") then
			--   ...（省略：blink 目前没有 formatting 钩子）
			-- end

			-- 只保留一次 setup

			-- 手动控制补全的键位（blink 的 keymap 里没有 toggle，这里给一个"显式呼出"）
			-- 说明：插入模式，用 Alt-/ 打开补全；关闭用你已经配置的 <C-e>（hide）
		end,
	},
}
