return {
	-- Parser 安装管理
	{
		"lewis6991/ts-install.nvim",
		dependencies = {
			-- ts-install 内部依赖 nvim-treesitter 的 parser 定义和 query 文件
			{ "nvim-treesitter/nvim-treesitter", branch = "main" },
		},
		config = function()
			require("ts-install").setup({
				auto_update = false,
				ensure_install = {
					"lua",
					"python",
					"go",
					"json",
					"yaml",
					"bash",
					"markdown",
					"markdown_inline",
					"html",
					"javascript",
					"toml",
					"typescript",
					"latex",
					"terraform",
					"just",
					"rust",
					"zig",
					"typst",
					-- Scheme 系：Racket 和 Scheme 共享 Lisp s-expr 语法但 grammar 是分开的；
					-- racket parser 主要处理 #lang / Racket 特有的 syntax sugar
					"scheme",
					"racket",
					"d2",
				},
				auto_install = true,
			})

			-- Treesitter 高亮（Neovim 0.12 原生 API）
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true }),
				callback = function(ev)
					local buf = ev.buf
					if not vim.api.nvim_buf_is_valid(buf) then
						return
					end
					local ft = vim.bo[buf].filetype
					-- chezmoi.vim 用传统 syntax/ 文件叠加 go-template 高亮；TS
					-- highlight 一启会盖掉。复合 ft 如 `toml.chezmoitmpl` 上
					-- get_lang 通常也返回 nil 自然跳过，但 ft="chezmoitmpl"
					-- 单独出现时会查到 parser，需显式拦截。
					if ft:find("chezmoitmpl") then
						return
					end
					-- csv/tsv/psv 的列高亮交给 csvview.nvim(每列彩虹 + 对齐,见
					-- lua/plugins/lang/csv.lua)。treesitter 的类型配色会和它在
					-- 同一格抢 extmark 优先级,这里跳过,让 csvview 独占 CSV 渲染。
					if ft == "csv" or ft == "tsv" or ft == "psv" then
						return
					end
					local lang = vim.treesitter.language.get_lang(ft)
					if not lang then
						return
					end
					if pcall(vim.treesitter.language.add, lang) then
						pcall(vim.treesitter.start, buf, lang)
					end
				end,
			})
		end,
	},
}
