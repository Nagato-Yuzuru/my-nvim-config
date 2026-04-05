-- lua/plugins/edit/fold.lua
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
				function()
					require("ufo").openAllFolds()
				end,
				desc = "UFO: open all folds",
			},
			{
				"zM",
				function()
					require("ufo").closeAllFolds()
				end,
				desc = "UFO: close all folds",
			},
			{
				"zr",
				function()
					require("ufo").openFoldsExceptKinds()
				end,
				desc = "UFO: open folds (smart)",
			},
			{
				"zm",
				function()
					require("ufo").closeFoldsWith()
				end,
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
			-- Treesitter 可用时优先用 TS，其次缩进；有些 LSP 也能提供 foldingRange
			require("ufo").setup({
				provider_selector = function(_, filetype, _)
					local ok = pcall(vim.treesitter.get_parser, bufnr)
					if ok then
						return { "treesitter", "indent" }
					else
						return { "indent" }
					end
				end,
				-- 可选：自定义折叠行的虚拟文本
				-- fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
				--   local newVirtText = {}
				--   local suffix = ("  ↙ %d lines "):format(endLnum - lnum)
				--   local sufWidth = vim.fn.strdisplaywidth(suffix)
				--   local targetWidth = width - sufWidth
				--   local curWidth = 0
				--   for _, chunk in ipairs(virtText) do
				--     local txt, hl = chunk[1], chunk[2]
				--     local len = vim.fn.strdisplaywidth(txt)
				--     if targetWidth > curWidth + len then
				--       table.insert(newVirtText, chunk)
				--       curWidth = curWidth + len
				--     else
				--       txt = truncate(txt, targetWidth - curWidth)
				--       table.insert(newVirtText, { txt, hl })
				--       break
				--     end
				--   end
				--   table.insert(newVirtText, { suffix, "Comment" })
				--   return newVirtText
				-- end,
			})
		end,
	},
}
