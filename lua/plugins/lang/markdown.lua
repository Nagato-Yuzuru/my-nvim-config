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
		-- 光标行在 n/v/c 模式保持 conceal（默认 concealcursor="" 会在光标行
		-- 闪回原始 markdown 源码），配合上面 anti_conceal 的豁免项使用
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
		-- `` ` `` 是全局键（任何 buffer 按了都该工作），用 lazy 的 keys 触发而非 ft：
		-- ft="markdown" 会把插件锁在 markdown buffer 上加载，而这个键是全局绑定，
		-- 其它 filetype 触发时会撞 E492: Not an editor command: Switch。keys 触发下
		-- 首次按 ` 时载入插件 + 同步把键映射上去，之后直接执行。custom_definitions
		-- 走 init（lazy 在 plugin load 前就跑 init），所以即便在 Go / lua 里按 ` 也
		-- 能用上自定义模式（不匹配就 fallback 到 switch.vim 内置语言规则）。
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
		-- 插件默认 bullets_enabled_file_types = markdown/text/gitcommit —— ft 只管
		-- 惰性加载，一旦载入就会在 text / gitcommit buffer 里也抢 o / <leader>x / >> / <<。
		init = function() vim.g.bullets_enabled_file_types = { "markdown" } end,
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
				-- IM7 原生写法;`magick convert` 已被 IM7 标记弃用并告警
				process_cmd = "magick - -quality 75 avif:-",
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
					process_cmd = "magick - -density 300 png:-",
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
			-- ,mr/,mR 把文字装饰(render-markdown)和图片(snacks.image,经
			-- tools/image_render)当一个"渲染视图"整体开关:先算出目标状态
			-- 再对两边显式 set,避免各自独立 toggle 后状态漂移(如先用 ,ii
			-- 单独关过图片)。buffer 级状态读 render-markdown 内部 state
			-- (无公开 buf 级 getter),更新后需复查。
			{
				"<localleader>mr",
				function()
					local buf = vim.api.nvim_get_current_buf()
					local on = not require("render-markdown.state").get(buf).enabled
					require("render-markdown").set_buf(on)
					require("tools.image_render").buf_set(buf, on)
				end,
				ft = { "markdown", "markdown.mdx" },
				desc = "MD: Toggle render + images (buffer)",
			},
			{
				"<localleader>mR",
				function()
					local rm = require("render-markdown")
					local on = not rm.get()
					rm.set(on)
					require("tools.image_render").global_set(on)
				end,
				ft = { "markdown", "markdown.mdx" },
				desc = "MD: Toggle render + images (global)",
			},
			{
				"<localleader>mp",
				function() require("render-markdown").preview() end,
				ft = { "markdown", "markdown.mdx" },
				desc = "MD: Preview (split)",
			},
		},
	},
	{
		-- 浏览器实时预览 —— mermaid / KaTeX 数学的唯一渲染出口。
		-- 分工:buffer 内装饰归 render-markdown,普通图片归 snacks.image,
		-- 图形化(mermaid/数学/整体排版)归浏览器。后端纯 Lua HTTP server,
		-- mermaid-js/KaTeX 在浏览器端渲染,零二进制依赖 —— 刻意不装
		-- mmdc(=puppeteer+headless Chromium)和 tectonic/TeX,见
		-- lua/plugins/ui/snacks.lua 的 image 注释。
		-- markdown/asciidoc/svg 边打字边刷新;滚动单向同步(nvim → 浏览器)。
		"brianhuster/live-preview.nvim",
		cmd = "LivePreview",
		-- opts 不可用:插件的 setup() 只是标了 @deprecated 的兼容壳,
		-- 文档正道是 livepreview.config.set(),故用 config 函数。
		config = function()
			require("livepreview.config").set({
				-- webroot 取当前文件所在目录而非 cwd —— 笔记常从 vault 外
				-- 打开,img-clip 的附件是 ./attachments 相对文件存放,
				-- 不开这个 cwd 外的文件相对图片路径会 404。
				dynamic_root = true,
			})
		end,
		keys = {
			{
				"<localleader>mb",
				function()
					local lp = require("livepreview")
					if lp.is_running() then
						lp.close()
						vim.notify("LivePreview stopped")
					else
						vim.cmd("LivePreview start")
					end
				end,
				ft = { "markdown", "markdown.mdx" },
				desc = "MD: Preview (browser, toggle)",
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
