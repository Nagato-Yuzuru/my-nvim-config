return {
	"nvim-treesitter/nvim-treesitter-textobjects",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	event = "VeryLazy",
	config = function()
		require("nvim-treesitter-textobjects").setup({
			select = { lookahead = true },
			move = { set_jumps = true },
		})

		local select = require("nvim-treesitter-textobjects.select")
		local move = require("nvim-treesitter-textobjects.move")
		local swap = require("nvim-treesitter-textobjects.swap")

		local map = function(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, desc = desc })
		end

		-- Select textobjects
		local selections = {
			["af"] = "@function.outer",
			["if"] = "@function.inner",
			["ac"] = "@class.outer",
			["ic"] = "@class.inner",
			["aa"] = "@parameter.outer",
			["ia"] = "@parameter.inner",
			["ai"] = "@conditional.outer",
			["ii"] = "@conditional.inner",
			["al"] = "@loop.outer",
			["il"] = "@loop.inner",
		}
		for key, query in pairs(selections) do
			map({ "x", "o" }, key, function()
				select.select_textobject(query)
			end, "TS: " .. query)
		end

		-- Move to next/prev function and argument
		local moves = {
			["]f"] = { move.goto_next_start, "@function.outer", "Next function start" },
			["]F"] = { move.goto_next_end, "@function.outer", "Next function end" },
			["[f"] = { move.goto_previous_start, "@function.outer", "Prev function start" },
			["[F"] = { move.goto_previous_end, "@function.outer", "Prev function end" },
			["]a"] = { move.goto_next_start, "@parameter.outer", "Next argument" },
			["[a"] = { move.goto_previous_start, "@parameter.outer", "Prev argument" },
		}
		for key, spec in pairs(moves) do
			map({ "n", "x", "o" }, key, function()
				spec[1](spec[2])
			end, "TS: " .. spec[3])
		end

		-- Swap arguments
		map("n", "gsa", function()
			swap.swap_next("@parameter.inner")
		end, "Swap with next argument")
		map("n", "gsA", function()
			swap.swap_previous("@parameter.inner")
		end, "Swap with prev argument")
	end,
}
