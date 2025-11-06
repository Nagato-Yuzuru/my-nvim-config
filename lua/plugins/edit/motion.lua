-- lua/plugins/edit/motion.lua
-- Hop.nvim 完整配置 + EasyMotion 风格键位（无顶层 require）
local last_hop = nil

local function remember_and_run(run)
	return function()
		last_hop = run
		run()
	end
end

local function hop_repeat()
	if last_hop then
		last_hop()
	else
	end
end

return {
	{
		"phaazon/hop.nvim",
		branch = "v2",
		-- 用 keys 懒加载即可；不需要再配 event
		-- event = "VeryLazy",
		opts = {
			keys = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
			multi_windows = false,
		},
		config = function(_, opts)
			require("hop").setup(opts)
		end,
		keys = {
			-- 当前行左右
			{
				"<leader><leader>h",
				remember_and_run(function()
					local hop = require("hop")
					local hint = require("hop.hint")
					hop.hint_words({ direction = hint.HintDirection.BEFORE_CURSOR, current_line_only = true })
				end),
				mode = { "n", "x", "o" },
				desc = "Hop ← (line, words)",
			},
			{
				"<leader><leader>l",
				remember_and_run(function()
					local hop = require("hop")
					local hint = require("hop.hint")
					hop.hint_words({ direction = hint.HintDirection.AFTER_CURSOR, current_line_only = true })
				end),
				mode = { "n", "x", "o" },
				desc = "Hop → (line, words)",
			},

			-- 上下行
			{
				"<leader><leader>j",
				remember_and_run(function()
					local hop = require("hop")
					local hint = require("hop.hint")
					hop.hint_lines_skip_whitespace({ direction = hint.HintDirection.AFTER_CURSOR })
				end),
				mode = { "n", "x", "o" },
				desc = "Hop ↓ lines",
			},
			{
				"<leader><leader>k",
				remember_and_run(function()
					local hop = require("hop")
					local hint = require("hop.hint")
					hop.hint_lines_skip_whitespace({ direction = hint.HintDirection.BEFORE_CURSOR })
				end),
				mode = { "n", "x", "o" },
				desc = "Hop ↑ lines",
			},

			-- 小写 web：当前行内
			{
				"<leader><leader>w",
				remember_and_run(function()
					local hop = require("hop")
					local hint = require("hop.hint")
					hop.hint_words({ direction = hint.HintDirection.AFTER_CURSOR, current_line_only = true })
				end),
				mode = { "n", "x", "o" },
				desc = "Hop word → (line)",
			},
			{
				"<leader><leader>b",
				remember_and_run(function()
					local hop = require("hop")
					local hint = require("hop.hint")
					hop.hint_words({ direction = hint.HintDirection.BEFORE_CURSOR, current_line_only = true })
				end),
				mode = { "n", "x", "o" },
				desc = "Hop word ← (line)",
			},
			{
				"<leader><leader>e",
				remember_and_run(function()
					local hop = require("hop")
					local hint = require("hop.hint")
					hop.hint_words({ direction = hint.HintDirection.AFTER_CURSOR, current_line_only = true })
					vim.cmd("normal! e")
				end),
				mode = { "n", "x", "o" },
				desc = "Hop word end → (line)",
			},

			-- 大写 WEB：非空白块，跨行
			{
				"<leader><leader>W",
				remember_and_run(function()
					local hop = require("hop")
					local hint = require("hop.hint")
					hop.hint_patterns({ direction = hint.HintDirection.AFTER_CURSOR, pattern = [[\S\+]] })
				end),
				mode = { "n", "x", "o" },
				desc = "Hop WORD →",
			},
			{
				"<leader><leader>B",
				remember_and_run(function()
					local hop = require("hop")
					local hint = require("hop.hint")
					hop.hint_patterns({ direction = hint.HintDirection.BEFORE_CURSOR, pattern = [[\S\+]] })
				end),
				mode = { "n", "x", "o" },
				desc = "Hop WORD ←",
			},
			{
				"<leader><leader>E",
				remember_and_run(function()
					local hop = require("hop")
					local hint = require("hop.hint")
					hop.hint_patterns({ direction = hint.HintDirection.AFTER_CURSOR, pattern = [[\S\+]] })
					vim.cmd("normal! E")
				end),
				mode = { "n", "x", "o" },
				desc = "Hop WORD end →",
			},

			-- 首字母跳（词首）
			{
				"<leader><leader>t",
				function()
					local hop = require("hop")
					local hint = require("hop.hint")
					local c = vim.fn.getcharstr()
					hop.hint_patterns({
						pattern = "\\<" .. vim.fn.escape(c, [[\]]),
						current_line_only = true,
						direction = hint.HintDirection.AFTER_CURSOR,
					})
				end,
				mode = { "n", "x", "o" },
				desc = "Hop word-start by first letter (line)",
			},
			{
				"<leader><leader>T",
				function()
					local hop = require("hop")
					local hint = require("hop.hint")
					local c = vim.fn.getcharstr()
					hop.hint_patterns({
						pattern = "\\<" .. vim.fn.escape(c, [[\]]),
						direction = hint.HintDirection.AFTER_CURSOR,
					})
				end,
				mode = { "n", "x", "o" },
				desc = "Hop word-start by first letter (buffer)",
			},

			-- 重复
			{ "<leader><leader>.", hop_repeat, mode = { "n", "x", "o" }, desc = "Hop repeat" },

			-- 双字符跳
			{
				"S",
				function()
					require("hop").hint_char2()
				end,
				mode = { "n", "x", "o" },
				desc = "Hop 2-char",
			},
		},
	},
}
