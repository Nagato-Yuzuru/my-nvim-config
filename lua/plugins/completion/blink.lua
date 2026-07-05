return {
	{
		"saghen/blink.cmp",
		-- Pin to v1: v2 is explicitly marked unstable / breaking in the README
		-- (config schema is still churning). Revisit when v2 ships stable.
		version = "1.*",
		event = { "InsertEnter", "CmdlineEnter" },
		dependencies = {
			-- friendly-snippets：blink 内建 `snippets` 源（default preset，走原生
			-- vim.snippet）会自动发现它（sources/snippets/default registry 里
			-- friendly_snippets 默认 true），无需 LuaSnip。
			"rafamadriz/friendly-snippets",
			"xzbdmw/colorful-menu.nvim",
		},
		build = "cargo +nightly build --release",
		opts = {
			fuzzy = { implementation = "prefer_rust" },
			keymap = { -- 常用键位
				preset = "none",
				["<cr>"] = { "accept", "fallback" },
				-- Tab 链（blink 内建动作按序组合）：菜单可见→接受，否则片段激活→跳下一个
				-- 占位（原生 vim.snippet，含 select-mode），否则→原生 <Tab>。每个内建命令
				-- 处理成功即返回 true 停链，否则 fall through（见 blink keymap/apply.lua）。
				-- 接受函数补全会落到 (placeholder)，下一次 <Tab> 即跳到下一个参数槽。
				["<Tab>"] = { "accept", "snippet_forward", "fallback" },
				["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
				-- Alt-/ 切换补全菜单：未显示则呼出（docs auto_show 会跟着出），已
				-- 显示则关闭——blink keymap 没有内建 toggle，用函数命令实现。
				-- is_menu_visible 只看菜单窗，不会被 ghost_text 干扰。
				["<A-/>"] = {
					function(cmp)
						if cmp.is_menu_visible() then
							return cmp.hide()
						end
						return cmp.show()
					end,
				},
				["<C-p>"] = { "select_prev", "fallback" }, -- 上一个
				["<C-n>"] = { "select_next", "fallback" }, -- 下一个
				["<C-b>"] = { "scroll_documentation_up", "fallback" },
				["<C-f>"] = { "scroll_documentation_down", "fallback" },
			},
			appearance = { nerd_font_variant = "mono" },
			sources = {
				default = { "lsp", "path", "buffer", "snippets" },
				-- Go IDEA 风「裸标识符 → 限定符号 + 自动 import」由 go-deep 补足（gopls 不做，
				-- 见 lua/plugins/completion/go_deep.lua + lsp/gopls.lua 注释）。per_filetype 会
				-- **替换**该 ft 的默认源,所以这里显式复列默认四个 + go_deep（go_deep 排首,让 stdlib
				-- 精确名优先浮出）。go_deep 自身 enabled() 再确认 gopls 已 attach。
				per_filetype = {
					go = { "go_deep", "lsp", "path", "snippets", "buffer" },
				},
				providers = {
					go_deep = { module = "go_deep.blink", async = true },
				},
			},
			completion = {
				menu = {
					border = "rounded",
					winblend = 0,
					-- colorful-menu.nvim：用 treesitter 高亮 query 重建补全项 label，并把
					-- label_description 并入 label，故 columns 无需单列 label_description。
					-- 见 colorful-menu README「use it in blink.cmp」。
					draw = {
						columns = { { "kind_icon" }, { "label", gap = 1 } },
						components = {
							label = {
								text = function(ctx) return require("colorful-menu").blink_components_text(ctx) end,
								highlight = function(ctx)
									return require("colorful-menu").blink_components_highlight(ctx)
								end,
							},
						},
					},
				},
				documentation = {
					auto_show = true,
					window = { border = "rounded", winblend = 0 },
				},
				-- IDEA 风：菜单高亮首项，但**不**把候选写进 buffer。
				-- 默认 v1 是 auto_insert = true —— 那种行为在 `buffer` 源（只有
				-- insertText 没有 textEdit）下边界不稳，容易出现 "le" + 接受 "len"
				-- = "lelen" 的拼接。这里只在 accept 时落地，与 IDEA 语义一致。
				list = {
					selection = { preselect = true, auto_insert = false },
				},
				-- 行内灰字预览首项——视觉上接近 IDEA 的"在光标处看到要补全的整体形状"。
				ghost_text = { enabled = true },
				-- 函数/方法补全自动补 (…)：
				--   · LSP item 自带 snippet（gopls usePlaceholders）→ blink 直接展开
				--   · LSP item 没 snippet → kind == Function/Method 时由 blink 补 ()
				--   · semantic_token_based 在 server 支持 semantic tokens 时更准（不会给
				--     变量误加括号），失败则回落到 kind 判定
				accept = {
					auto_brackets = {
						enabled = true,
						kind_resolution = {
							enabled = true,
							blocked_filetypes = { "typescriptreact", "javascriptreact" },
						},
						semantic_token_resolution = {
							enabled = true,
							blocked_filetypes = {},
							timeout_ms = 400,
						},
					},
				},
			},
			signature = { -- 插入时自动签名提示（与 insert <C-k> 手动触发互补）
				enabled = true,
				window = { border = "rounded", winblend = 0 },
			},
			-- 不设 snippets.preset：默认 "default" 走原生 vim.snippet，friendly-snippets
			-- 由内建 snippets 源自动发现（见 dependencies 注释）。
			cmdline = {
				keymap = {
					preset = "none",
					["<C-n>"] = { "select_next", "fallback" },
					["<C-p>"] = { "select_prev", "fallback" },
					["<Tab>"] = { "show", "select_next", "fallback" },
					["<S-Tab>"] = { "select_prev", "fallback" },
					["<cr>"] = { "fallback" },
					-- 行尾有 ghost text 则 accept，否则前进一字
					["<C-f>"] = {
						function(cmp)
							if vim.fn.getcmdpos() > #vim.fn.getcmdline() then
								return cmp.accept()
							end
							vim.api.nvim_feedkeys(
								vim.api.nvim_replace_termcodes("<Right>", true, true, true),
								"cn",
								false
							)
							return true
						end,
					},
				},
				completion = {
					-- 只在输入 : 命令时自动显示菜单；/ ? 搜索仍按原生行为
					menu = {
						auto_show = function() return vim.fn.getcmdtype() == ":" end,
					},
					-- 纯 ghost 模式：预选首项（ghost 立即显示），但不自动写入 cmdline。
					-- 覆盖 blink.cmp cmdline 模式默认的 auto_insert=true
					-- （见 blink.cmp 的 config/modes/cmdline.lua）。
					-- 流程：
					--   · 打开菜单：ghost 预览首项
					--   · Tab / S-Tab：在候选间移动 ghost，cmdline 保持不变
					--   · <C-f>：在行尾把 ghost 真写进 cmdline（已有绑定）
					--   · <CR>：执行命令（fallback，不 accept）
					list = {
						selection = { preselect = true, auto_insert = false },
					},
					ghost_text = { enabled = true },
				},
				-- 源的控制（一般默认就行；需要的话可增加 min_keyword_length 等）
				-- sources = {
				--   default = { "cmdline", "path" }, -- :cmd 时
				--   search  = { "buffer" },          -- / ? 时
				-- },
			},
		},
		config = function(_, opts)
			-- colorful-menu：treesitter 高亮补全 label（下面 menu.draw 的 label 组件引用它）
			require("colorful-menu").setup({})
			require("blink.cmp").setup(opts)

			-- cmdline Emacs/shell 风格导航
			local map = vim.keymap.set
			map("c", "<C-a>", "<Home>", { noremap = true })
			map("c", "<C-b>", "<Left>", { noremap = true })
			map("c", "<M-b>", "<S-Left>", { noremap = true })
			map("c", "<M-f>", "<S-Right>", { noremap = true })
			map("c", "<C-k>", function()
				local col = vim.fn.getcmdpos()
				vim.fn.setcmdline(vim.fn.getcmdline():sub(1, col - 1))
			end, { noremap = true })

			-- if pcall(require, "lspkind") then
			--   ...（省略：blink 目前没有 formatting 钩子）
			-- end

			-- 只保留一次 setup

			-- 手动控制补全的键位：插入模式用 Alt-/ 切换补全菜单（开/关同一个键），
			-- 实现见上面 keymap 里的 <A-/> 函数命令。
		end,
	},
}
