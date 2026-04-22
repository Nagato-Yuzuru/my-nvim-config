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

		-- Move to next/prev node by kind.
		-- Note: lowercase `]c`/`[c` is claimed by gitsigns (hunk nav), so class
		-- nav uses uppercase `]C`/`[C`. `[i` shadows the rarely-used builtin
		-- "search word in included files" — intentional.
		local moves = {
			["]f"] = { move.goto_next_start,     "@function.outer",    "Next function start" },
			["]F"] = { move.goto_next_end,       "@function.outer",    "Next function end" },
			["[f"] = { move.goto_previous_start, "@function.outer",    "Prev function start" },
			["[F"] = { move.goto_previous_end,   "@function.outer",    "Prev function end" },
			["]a"] = { move.goto_next_start,     "@parameter.outer",   "Next argument" },
			["[a"] = { move.goto_previous_start, "@parameter.outer",   "Prev argument" },
			["]l"] = { move.goto_next_start,     "@loop.outer",        "Next loop start" },
			["]L"] = { move.goto_next_end,       "@loop.outer",        "Next loop end" },
			["[l"] = { move.goto_previous_start, "@loop.outer",        "Prev loop start" },
			["[L"] = { move.goto_previous_end,   "@loop.outer",        "Prev loop end" },
			["]C"] = { move.goto_next_start,     "@class.outer",       "Next class" },
			["[C"] = { move.goto_previous_start, "@class.outer",       "Prev class" },
			["]i"] = { move.goto_next_start,     "@conditional.outer", "Next conditional" },
			["[i"] = { move.goto_previous_start, "@conditional.outer", "Prev conditional" },
		}
		for key, spec in pairs(moves) do
			map({ "n", "x", "o" }, key, function()
				spec[1](spec[2])
			end, "TS: " .. spec[3])
		end

		-- Swap siblings
		map("n", "gsa", function() swap.swap_next("@parameter.inner") end, "Swap with next argument")
		map("n", "gsA", function() swap.swap_previous("@parameter.inner") end, "Swap with prev argument")
		map("n", "gss", function() swap.swap_next("@statement.outer") end, "Swap with next statement")
		map("n", "gsS", function() swap.swap_previous("@statement.outer") end, "Swap with prev statement")

		-- ===== Incremental selection =====
		-- `<A-w>` grows the visual selection to the enclosing syntax node;
		-- `<A-W>` shrinks back one level. Mnemonic: w = widen. Mirrors IDEA's
		-- Ctrl+W / Ctrl+Shift+W (EditorSelectWord / EditorUnSelectWord) on the
		-- Windows/Linux keymap — those live in the IDE keymap, not .ideavimrc.
		--
		-- The stack resets the next time `<A-w>` is pressed from normal mode,
		-- so moving the cursor and re-expanding always starts fresh.
		local sel_stack = {}

		-- Walk up until we find a parent whose range is strictly larger than
		-- `node`. Grammar wrappers (expression, assignment_expression, etc.)
		-- often share their child's range and would make `<A-w>` look like it
		-- did nothing.
		local function next_larger(node)
			local srow, scol, erow, ecol = node:range()
			local p = node:parent()
			while p do
				local psr, psc, per, pec = p:range()
				if psr ~= srow or psc ~= scol or per ~= erow or pec ~= ecol then
					return p
				end
				p = p:parent()
			end
			return nil
		end

		local function select_node(node)
			local srow, scol, erow, ecol = node:range()
			local s_line, s_col = srow + 1, scol + 1
			local e_line, e_col
			if ecol == 0 then
				-- Node ends at column 0 of the next line; snap to end of previous line.
				e_line = erow
				local line = vim.api.nvim_buf_get_lines(0, erow - 1, erow, false)[1] or ""
				e_col = math.max(#line, 1)
			else
				e_line, e_col = erow + 1, ecol
			end

			local mode = vim.api.nvim_get_mode().mode
			if mode == "v" then
				-- Already in charwise visual: reposition BOTH ends without leaving
				-- visual. Without this, the anchor stays at the original `v` spot
				-- and expansion grows only on one side.
				vim.fn.setpos(".", { 0, e_line, e_col, 0 })  -- cursor → new end
				vim.cmd("normal! o")                         -- flip: anchor ↔ cursor
				vim.fn.setpos(".", { 0, s_line, s_col, 0 })  -- cursor → new start
			else
				-- Drop any non-charwise visual, then enter charwise fresh.
				if mode == "V" or mode == "\22" then
					vim.cmd("normal! \27")
				end
				vim.fn.setpos(".", { 0, s_line, s_col, 0 })
				vim.cmd("normal! v")
				vim.fn.setpos(".", { 0, e_line, e_col, 0 })
			end
		end

		local function ts_expand()
			local buf = vim.api.nvim_get_current_buf()
			-- Starting from normal mode always restarts the stack.
			if vim.api.nvim_get_mode().mode == "n" then
				sel_stack[buf] = nil
			end
			local stack = sel_stack[buf] or {}
			local top = stack[#stack]
			local node = top and next_larger(top) or vim.treesitter.get_node()
			if not node then return end
			stack[#stack + 1] = node
			sel_stack[buf] = stack
			select_node(node)
		end

		local function ts_shrink()
			local buf = vim.api.nvim_get_current_buf()
			local stack = sel_stack[buf]
			if not stack or #stack <= 1 then return end
			stack[#stack] = nil
			select_node(stack[#stack])
		end

		map({ "n", "x" }, "<A-w>", ts_expand, "TS: expand selection")
		map("x",           "<A-W>", ts_shrink, "TS: shrink selection")
	end,
}
