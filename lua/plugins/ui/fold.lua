-- lua/plugins/ui/fold.lua
return {
	{
		"kevinhwang91/nvim-ufo",
		dependencies = { "kevinhwang91/promise-async" },
		event = "VeryLazy",
		init = function()
			-- 推荐的全局折叠选项
			vim.o.foldcolumn = "1" -- 左侧显示折叠列
			vim.o.foldlevel = 99 -- 让大多数缓冲区默认展开
			vim.o.foldlevelstart = 99
			vim.o.foldenable = true
		end,
		keys = {
			{
				"zR",
				function() require("ufo").openAllFolds() end,
				desc = "UFO: open all folds",
			},
			{
				"zM",
				function() require("ufo").closeAllFolds() end,
				desc = "UFO: close all folds",
			},
			{
				"zr",
				function() require("ufo").openFoldsExceptKinds() end,
				desc = "UFO: open folds (smart)",
			},
			{
				"zm",
				function() require("ufo").closeFoldsWith() end,
				desc = "UFO: close folds (smart)",
			},
			-- 预览当前光标下的折叠块（不必先打开）
			{
				"<leader>zp",
				function()
					local winid = require("ufo").peekFoldedLinesUnderCursor()
					if not winid then
						vim.cmd.normal("za")
					end
				end,
				desc = "UFO: peek folded lines",
			},
		},
		config = function()
			-- UFO 的 provider_selector 只认 { main, fallback } 两档：main 拿不到
			-- 结果时才用 fallback，返回 3 个会报错。所以选一个最合适的 main，
			-- 再固定用 "indent" 兜底。LSP foldingRange 语义最准（jsonls 能合并
			-- 注释块、lua_ls 能按作用域），没 LSP 时退到 treesitter（结构折叠），
			-- 再退到 indent。
			require("ufo").setup({
				provider_selector = function(bufnr, _filetype, _buftype)
					for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
						if client:supports_method("textDocument/foldingRange") then
							return { "lsp", "indent" }
						end
					end
					if pcall(vim.treesitter.get_parser, bufnr) then
						return { "treesitter", "indent" }
					end
					return { "indent" }
				end,
			})
		end,
	},
}
