return {
	"nvim-treesitter/nvim-treesitter-textobjects",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		-- 键位归属，不是普通依赖：vim-indent-object 在 plugin/indent-object.vim
		-- 里硬编码 onoremap/vnoremap ai/ii/aI/iI（无开关变量），和下面 selections
		-- 的 @conditional 撞 ai/ii。两边原本都是 VeryLazy，谁后 set 谁赢——同一个
		-- 文件冷启动两次实测结果不同。声明成依赖让 lazy 保证它先加载，本文件的
		-- ai/ii 必然覆盖在后。
		--
		-- 归属结论：ai/ii = 条件语句；缩进对象只剩 aI/iI（上游 README：iI ≡ ii，
		-- 主力键无损失；aI = 块 + 上下各一行，比原 ai 多吃一行）。
		--
		-- 不能删它换成内建 an/in（0.12 的 treesitter 节点对象）：Helm 模板 ft=yaml，
		-- 但 {{ }} 不是合法 YAML，parser 会把整棵树塌成一个 ERROR 节点，treesitter
		-- 系在那里全废；只有纯空白语义的缩进对象还能用。
		"michaeljsmith/vim-indent-object",
	},
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

		-- 无匹配时 select.select_textobject() 静默返回（上游行为，见 select.lua
		-- 的 `if range6 then`）。visual 里无害，但 operator-pending 里算子会落在
		-- 光标处的零宽区间：`dal` 只是空操作，`ysal(` 却会就地插入一对空 `()`
		-- 污染 buffer，`cal` 会莫名进插入模式。内建文本对象（`i(`）无匹配时由
		-- Vim 直接中止算子——这里补齐同样的语义：无匹配 ⇒ 仍停在 operator-pending
		-- （mode 前缀 "no"），据此喂 <Esc> 撤掉算子。
		--
		-- feedkeys 必须带 "i"（插到 typeahead 队首）：默认的追加语义会让 <Esc>
		-- 排在算子结算之后才被读到，`ys` 的 operatorfunc 早已跑完（实测 `ysal(`
		-- 仍插入空 `()`）。"x"（立即执行）则会把人卡在 operator-pending。
		local function select_or_abort(query)
			return function()
				select.select_textobject(query)
				if vim.api.nvim_get_mode().mode:sub(1, 2) == "no" then
					vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "ni", false)
				end
			end
		end

		-- Select textobjects
		--
		-- av/iv 对外叫「值」而不是 assignment：capture 名是实现细节，而 aa/ia 在
		-- 代码里已经是「参数」(@parameter)，再多一个 a 打头的概念只会互相干扰。
		-- iv = 值本身，在 yaml/json 里就是那个 key 底下的整棵子树（由树定边界，
		-- 不是「所有缩进 ≥ N 的行」）；av = 值连它的键。代码里两者同样成立：
		-- `civ` 改 `msg = "hi " .. name` 的右边，`cav` 改整条。
		--
		-- @assignment.lhs（只要键）故意不绑：改键名多数时候是 ciw，等真出现第二
		-- 个具体用例再补 ak/ik。json 的 query 里 lhs 已经备好了。
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
			["av"] = "@assignment.outer",
			["iv"] = "@assignment.rhs",
		}
		for key, query in pairs(selections) do
			map({ "x", "o" }, key, select_or_abort(query), "TS: " .. query)
		end

		-- Move to next/prev node by kind.
		--
		-- Convention: `]<lowercase>` = jump to next START of that text-object;
		-- `[<lowercase>` = previous start. NO end-variant bindings (no `]F`/`]L`
		-- /etc.) — uniform across all five kinds (function/loop/class/conditional
		-- /argument). `]f` (next function start) is the better "skip past
		-- current" key anyway, and end positioning without an operation is rare
		-- (use `vaf`/`daf` text-objects for ops; use matchup `%` to cycle within
		-- a block).
		--
		-- Exceptions to the lowercase rule:
		--   `]C`/`[C` class — uppercase to avoid gitsigns claiming `]c`/`[c`.
		--   `[i` conditional — shadows vim's builtin "search word in included
		--                      files" (`:help [i`); intentional, that builtin
		--                      is rarely useful outside C-with-headers workflows.
		local moves = {
			["]f"] = { move.goto_next_start, "@function.outer", "Next function start" },
			["[f"] = { move.goto_previous_start, "@function.outer", "Prev function start" },
			["]a"] = { move.goto_next_start, "@parameter.outer", "Next argument" },
			["[a"] = { move.goto_previous_start, "@parameter.outer", "Prev argument" },
			["]l"] = { move.goto_next_start, "@loop.outer", "Next loop start" },
			["[l"] = { move.goto_previous_start, "@loop.outer", "Prev loop start" },
			["]C"] = { move.goto_next_start, "@class.outer", "Next class" },
			["[C"] = { move.goto_previous_start, "@class.outer", "Prev class" },
			["]i"] = { move.goto_next_start, "@conditional.outer", "Next conditional" },
			["[i"] = { move.goto_previous_start, "@conditional.outer", "Prev conditional" },
		}
		for key, spec in pairs(moves) do
			map({ "n", "x", "o" }, key, function() spec[1](spec[2]) end, "TS: " .. spec[3])
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
				vim.fn.setpos(".", { 0, e_line, e_col, 0 }) -- cursor → new end
				vim.cmd("normal! o") -- flip: anchor ↔ cursor
				vim.fn.setpos(".", { 0, s_line, s_col, 0 }) -- cursor → new start
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
			if not node then
				return
			end
			stack[#stack + 1] = node
			sel_stack[buf] = stack
			select_node(node)
		end

		local function ts_shrink()
			local buf = vim.api.nvim_get_current_buf()
			local stack = sel_stack[buf]
			if not stack or #stack <= 1 then
				return
			end
			stack[#stack] = nil
			select_node(stack[#stack])
		end

		map({ "n", "x" }, "<A-w>", ts_expand, "TS: expand selection")
		map("x", "<A-W>", ts_shrink, "TS: shrink selection")
	end,
}
