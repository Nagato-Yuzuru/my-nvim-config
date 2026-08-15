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
		-- 自写逻辑（无命中中止 operator + 增量选区）在 tools/ts_select.lua
		-- （tested seam，spec: tests/test_ts_select.lua）；本文件只接线。
		local ts_select = require("tools.ts_select")

		local map = function(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, desc = desc })
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
			map({ "x", "o" }, key, ts_select.select_or_abort(select.select_textobject, query), "TS: " .. query)
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

		-- Incremental selection：`<A-w>` 扩到外层语法节点，`<A-W>` 缩回一级。
		-- Mnemonic: w = widen. Mirrors IDEA's Ctrl+W / Ctrl+Shift+W
		-- (EditorSelectWord / EditorUnSelectWord) on the Windows/Linux keymap —
		-- those live in the IDE keymap, not .ideavimrc.
		-- 栈语义（normal 起手重置、per-buffer）见 tools/ts_select.lua。
		map({ "n", "x" }, "<A-w>", ts_select.expand, "TS: expand selection")
		map("x", "<A-W>", ts_select.shrink, "TS: shrink selection")
	end,
}
