local markdown_cfg = function()
	require("render-markdown").setup({
		callout = {
			abstract = {
				raw = "[!ABSTRACT]",
				rendered = "󰯂 Abstract",
				highlight = "RenderMarkdownInfo",
				category = "obsidian",
			},
			summary = {
				raw = "[!SUMMARY]",
				rendered = "󰯂 Summary",
				highlight = "RenderMarkdownInfo",
				category = "obsidian",
			},
			tldr = { raw = "[!TLDR]", rendered = "󰦩 Tldr", highlight = "RenderMarkdownInfo", category = "obsidian" },
			failure = {
				raw = "[!FAILURE]",
				rendered = " Failure",
				highlight = "RenderMarkdownError",
				category = "obsidian",
			},
			fail = { raw = "[!FAIL]", rendered = " Fail", highlight = "RenderMarkdownError", category = "obsidian" },
			missing = {
				raw = "[!MISSING]",
				rendered = " Missing",
				highlight = "RenderMarkdownError",
				category = "obsidian",
			},
			attention = {
				raw = "[!ATTENTION]",
				rendered = " Attention",
				highlight = "RenderMarkdownWarn",
				category = "obsidian",
			},
			warning = {
				raw = "[!WARNING]",
				rendered = " Warning",
				highlight = "RenderMarkdownWarn",
				category = "github",
			},
			danger = {
				raw = "[!DANGER]",
				rendered = " Danger",
				highlight = "RenderMarkdownError",
				category = "obsidian",
			},
			error = {
				raw = "[!ERROR]",
				rendered = " Error",
				highlight = "RenderMarkdownError",
				category = "obsidian",
			},
			bug = { raw = "[!BUG]", rendered = " Bug", highlight = "RenderMarkdownError", category = "obsidian" },
			quote = {
				raw = "[!QUOTE]",
				rendered = " Quote",
				highlight = "RenderMarkdownQuote",
				category = "obsidian",
			},
			cite = { raw = "[!CITE]", rendered = " Cite", highlight = "RenderMarkdownQuote", category = "obsidian" },
			todo = { raw = "[!TODO]", rendered = " Todo", highlight = "RenderMarkdownInfo", category = "obsidian" },
			wip = { raw = "[!WIP]", rendered = "󰦖 WIP", highlight = "RenderMarkdownHint", category = "obsidian" },
			done = {
				raw = "[!DONE]",
				rendered = " Done",
				highlight = "RenderMarkdownSuccess",
				category = "obsidian",
			},
		},
		sign = { enabled = false },
		code = {
			-- general
			width = "block",
			min_width = 80,
			-- borders
			border = "thin",
			left_pad = 1,
			right_pad = 1,
			-- language info
			position = "right",
			language_icon = true,
			language_name = true,
			-- avoid making headings ugly
			highlight_inline = "RenderMarkdownCodeInfo",
		},
		heading = {
			icons = { " 󰼏 ", " 󰎨 ", " 󰼑 ", " 󰎲 ", " 󰼓 ", " 󰎴 " },
			border = true,
			render_modes = true, -- keep rendering while inserting
		},
		checkbox = {
			unchecked = {
				icon = "󰄱",
				highlight = "RenderMarkdownCodeFallback",
				scope_highlight = "RenderMarkdownCodeFallback",
			},
			checked = {
				icon = "󰄵",
				highlight = "RenderMarkdownUnchecked",
				scope_highlight = "RenderMarkdownUnchecked",
			},
			custom = {
				question = {
					raw = "[?]",
					rendered = "",
					highlight = "RenderMarkdownError",
					scope_highlight = "RenderMarkdownError",
				},
				todo = {
					raw = "[>]",
					rendered = "󰦖",
					highlight = "RenderMarkdownInfo",
					scope_highlight = "RenderMarkdownInfo",
				},
				canceled = {
					raw = "[-]",
					rendered = "",
					highlight = "RenderMarkdownCodeFallback",
					scope_highlight = "@text.strike",
				},
				important = {
					raw = "[!]",
					rendered = "",
					highlight = "RenderMarkdownWarn",
					scope_highlight = "RenderMarkdownWarn",
				},
				favorite = {
					raw = "[~]",
					rendered = "",
					highlight = "RenderMarkdownMath",
					scope_highlight = "RenderMarkdownMath",
				},
			},
		},
		pipe_table = {
			alignment_indicator = "─",
			border = { "╭", "┬", "╮", "├", "┼", "┤", "╰", "┴", "╯", "│", "─" },
		},
		link = {
			wiki = { icon = " ", highlight = "RenderMarkdownWikiLink", scope_highlight = "RenderMarkdownWikiLink" },
			image = " ",
			custom = {
				github = { pattern = "github", icon = " " },
				gitlab = { pattern = "gitlab", icon = "󰮠 " },
				youtube = { pattern = "youtube", icon = " " },
				cern = { pattern = "cern.ch", icon = " " },
			},
			hyperlink = " ",
		},
		anti_conceal = {
			disabled_modes = { "n" },
			ignore = {
				bullet = true, -- render bullet in insert mode
				head_border = true,
				head_background = true,
			},
		},
		-- https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/509
		win_options = { concealcursor = { rendered = "nvc" } },
		completions = {
			blink = { enabled = true },
			lsp = { enabled = true },
		},
	})
end

return {
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown", "markdown.mdx" },
		config = markdown_cfg,
	},
	{
		"AndrewRadev/switch.vim",
		-- `` ` `` 是全局键（任何 buffer 按了都该工作）。原先 ft="markdown" 把
		-- 插件锁在 markdown buffer 上加载，core/keymaps.lua 里全局绑的 ` 在
		-- 其它文件里就会撞 E492: Not an editor command: Switch。
		-- 改用 lazy 的 keys 触发：首次按 ` 时载入插件 + 同步把键映射上去，
		-- 之后直接执行。custom_definitions 走 init（lazy 在 plugin load 前
		-- 就跑 init），所以即便在 Go / lua 里按 ` 也能用上自定义模式（不匹
		-- 配就 fallback 到 switch.vim 内置语言规则）。
		keys = {
			{ "`", "<cmd>Switch<cr>", desc = "Switch under cursor" },
		},
		init = function()
			vim.g.switch_custom_definitions = {
				{ "> [!TODO]", "> [!WIP]", "> [!DONE]", "> [!FAIL]" },
				{ "height", "width" },
			}
		end,
	},
	{
		"bullets-vim/bullets.vim",
		ft = { "markdown" },
	},
	{
		"HakonHarnes/img-clip.nvim",
		ft = { "tex", "markdown", "typst" },
		opts = {
			default = {
				dir_path = "./attachments",
				use_absolute_path = false,
				copy_images = true,
				prompt_for_file_name = false,
				file_name = "%y%m%d-%H%M%S",
				extension = "avif",
				process_cmd = "magick convert - -quality 75 avif:-",
			},
			filetypes = {
				markdown = {
					template = "![image$CURSOR]($FILE_PATH)",
				},
				tex = {
					dir_path = "./figs",
					extension = "png",
					process_cmd = "",
					template = [[
    \begin{figure}[h]
      \centering
      \includegraphics[width=0.8\textwidth]{$FILE_PATH}
    \end{figure}
        ]], ---@type string | fun(context: table): string
				},
				typst = {
					dir_path = "./figs",
					extension = "png",
					process_cmd = "magick convert - -density 300 png:-",
					template = [[
          #align(center)[#image("$FILE_PATH", height: 80%)]
          ]],
				},
			},
		},
		keys = {
			{
				"<localleader>P",
				"<cmd>PasteImage<cr>",
				ft = { "markdown", "markdown.mdx", "tex", "typst" },
				desc = "Paste image from system clipboard",
			},
			{
				"<localleader>mr",
				function()
					require("render-markdown").set_buf()
				end,
				ft = { "markdown", "markdown.mdx" },
				desc = "MD: Toggle render (buffer)",
			},
			{
				"<localleader>mR",
				function()
					require("render-markdown").toggle()
				end,
				ft = { "markdown", "markdown.mdx" },
				desc = "MD: Toggle render (global)",
			},
			{
				"<localleader>mp",
				function()
					require("render-markdown").preview()
				end,
				ft = { "markdown", "markdown.mdx" },
				desc = "MD: Preview (split)",
			},
		},
	},
	{
		"preservim/vim-markdown",
		dependencies = { "godlygeek/tabular" },
		ft = { "markdown" },
		init = function()
			-- 折叠由 treesitter / nvim-ufo 提供，不让 vim-markdown 抢
			-- 'foldexpr' / 'foldmethod'，否则一打开 .md 两边互相覆盖。
			vim.g.vim_markdown_folding_disabled = 1
			vim.g.vim_markdown_conceal = 0
			vim.g.vim_markdown_math = 1
			vim.g.vim_markdown_frontmatter = 1
			vim.g.vim_markdown_new_list_item_indent = 2
		end,
	},
}
