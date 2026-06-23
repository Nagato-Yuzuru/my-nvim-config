---
--- refactoring.nvim — treesitter-based 跨语言重构
--- 填补 LSP CodeActionKind 粒度不足的空白：LSP 只有 refactor.extract 一层，
--- 区分不出"提取函数 / 提取变量 / 提取到新文件"；refactoring.nvim 用
--- treesitter 静态分析，对它支持的语言（JS/TS/Lua/Python/Go/C/C++/Java/
--- Ruby/PHP）能直接给到键级粒度。
---
--- 与 LSP refactor 的分工（详见 lua/core/lsp.lua "Refactor 命名空间" 注释）：
---   refactoring.nvim → extract 三连（treesitter，提供 LSP 没有的键级粒度）
---   LSP code action  → refactor.{inline,rewrite,move} + 全菜单
---   inc-rename       → rename（lua/plugins/lsp/inc-rename.lua）
---
--- <leader>rl 是 LSP-first 自动 fallback 调度器（见 lsp_inline_then_treesitter）：
--- 先 buf_request_all 查 refactor.inline 类 code action，任意 server 有就走
--- nvim 原生 picker；全空才 feedkeys 给 refactoring.nvim 的 inline_var 兜底。
--- 双 RTT 代价 ~150-300ms，换取"按一个键、永远能用"。
---
--- <leader>rv（normal）是对称的智能提取调度器（见 extract_var_smart）：
--- refactoring.nvim 的 extract_var 在 normal 只返回 "g@"（operatorfunc），按一下会
--- 等 motion；而 JetBrains 直接提取光标处表达式、歧义时弹列表。这里用 treesitter 收集
--- 光标处的命名表达式祖先（多个则 vim.ui.select 选），选定后高亮预览，再走和 inline
--- 同一套 LSP-first / refactoring.nvim 兜底分派。visual 模式 <leader>rv 不变。
---
--- API 说明：refactoring.nvim 用 operatorfunc 模式 —— 函数返回 "g@"，
--- 通过 `expr = true` 让 nvim 接管 motion/textobject。这样同一个键在
--- normal 模式下可以接 textobject（如 `<leader>rmiw`），visual 模式下
--- 直接对选区生效。所有键 mode 都是 {"n","x"}。
---
--- IdeaVim 侧 <leader>r{v,c,f,m,p,i} 在 IDE 里是六个独立动作；refactoring.nvim
--- 只在概念上重合 m=ExtractMethod / v=IntroduceVariable，其余（Constant /
--- IntroduceField / Parameter / ExtractInterface）没有对应物，**按 parity 原则
--- 保持留空**而不是挂个错位语义（同键不同义比缺键更伤肌肉记忆）。
---

local function expr_keymap(lhs, fn_name, desc)
	return {
		lhs,
		function() return require("refactoring")[fn_name]() end,
		mode = { "n", "x" },
		expr = true,
		desc = desc,
	}
end

-- LSP-first code-action 调度的共用骨架（<leader>rl inline 与 <leader>rv extract 共用）：
-- 异步问 attached LSP 有没有 `kind` 类 code action，有就 reselect() 后交给 nvim 原生
-- picker（vim.lsp.buf.code_action，省得自己实现 apply/resolve/command）；无 client 或全空
-- 就 fallback()（喂 refactoring.nvim 的 operatorfunc 兜底）。双 RTT：pre-query 只为判空，
-- 命中后再正式调 code_action 走标准路径。
--
-- range 来源（make_params）与命中后是否 gv 重选（reselect）由调用方决定 —— inline 可能在
-- normal 也可能在 visual、extract 则总是已选好一个节点 range，仅这两点不同，其余全同。
--
-- 注：make_*_range_params 的类型签名只声明 textDocument + range、不含 context，而实际的
-- lsp.CodeActionParams 是其超集，故调用方的 make_params 里 cast 一下让 Lua-LS 闭嘴。
---@param bufnr integer
---@param kind string  CodeActionKind 前缀，如 "refactor.inline" / "refactor.extract"
---@param make_params fun(bufnr: integer, enc: string): lsp.CodeActionParams
---@param reselect fun()|nil  命中后、调 code_action 前调用（重进 visual）
---@param fallback fun()  无 client / 无对应 code action 时的兜底
local function lsp_first_code_action(bufnr, kind, make_params, reselect, fallback)
	local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/codeAction" })
	if #clients == 0 then
		return fallback()
	end

	local enc = clients[1].offset_encoding or "utf-16"
	local params = make_params(bufnr, enc)
	params.context = { only = { kind }, diagnostics = {} }

	vim.lsp.buf_request_all(bufnr, "textDocument/codeAction", params, function(results)
		local has_action = false
		for _, r in pairs(results or {}) do
			if r.result and #r.result > 0 then
				has_action = true
				break
			end
		end
		vim.schedule(function()
			if has_action then
				if reselect then
					reselect()
				end
				vim.lsp.buf.code_action({ context = { only = { kind }, diagnostics = {} } })
			else
				fallback()
			end
		end)
	end)
end

-- <leader>rl inline 调度器：refactor.inline → refactoring.nvim inline_var 兜底（"g@l" 走
-- operatorfunc）。mode 处理：
--   - visual: 键消耗后 visual 已退出、'< '> marks 仍记得选区 → 先 \27 让 marks 稳定，
--     用 make_given_range_params；命中后 gv 重进 visual（否则 code_action 用 cursor pos）。
--   - normal: make_range_params 用 cursor 位置，命中后无需 gv。
local function lsp_inline_then_treesitter()
	local mode = vim.api.nvim_get_mode().mode
	local is_visual = mode == "v" or mode == "V" or mode == "\22"
	local bufnr = vim.api.nvim_get_current_buf()

	-- \27 放进 make_params（只在有 client 时被调用），保持原行为：无 client 直接 fallback
	-- 时不离开 visual（inline_var 的 "g@l" 自带 motion，与选区无关）。
	local make_params = function(b, enc)
		if is_visual then
			-- 离开 visual 让 '< '> marks 稳定（visual 中 marks 动态），再取 last-visual range
			vim.cmd("normal! \27")
			return vim.lsp.util.make_given_range_params(nil, nil, b, enc) --[[@as lsp.CodeActionParams]]
		end
		return vim.lsp.util.make_range_params(0, enc) --[[@as lsp.CodeActionParams]]
	end

	local reselect
	if is_visual then
		reselect = function() vim.cmd("normal! gv") end
	end

	local fallback = function()
		local keys = require("refactoring").inline_var()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
	end

	lsp_first_code_action(bufnr, "refactor.inline", make_params, reselect, fallback)
end

local extract_preview_ns = vim.api.nvim_create_namespace("refactor_extract_var_preview")

-- 候选收集是结构化分类，**不依赖 grammar 的 supertype 元数据**——实测 supertype
-- 不可靠：tree-sitter-lua 的 `expression` supertype 竟含 assignment_statement、且
-- 漏掉 binary_expression / identifier（python/js 的反而正确，但不能只服务一部分语言）。
-- 三条结构化规则即可干净覆盖 lua/python/js/ts/c/go/rust：
--   · is_stmt_boundary：遇语句/块/声明边界停（按类型名模式匹配，best-effort）。
--   · NON_EXPR_TYPES：跳过结构化的"非表达式"节点——实参/形参容器（调用括号 (a, b)）
--     与字面量条目（go keyed_element / rust field_initializer / js·py pair 的 key: value，
--     都不是独立表达式）；集合字面量本身 {..}/[..] 不在此列，照常保留。
--   · has_assign_token：跳过带裸 "=" 子 token 的节点（赋值/声明符/默认参数/kwarg），
--     避免把整条 `r = foo(...)` 当候选。

-- 语句/块/声明边界：表达式不会跨过这些节点。grammar 命名不统一，用模式匹配近似。
local function is_stmt_boundary(node_type)
	return node_type:find("statement", 1, true)
		or node_type:find("declaration", 1, true)
		or node_type:find("block", 1, true)
		or node_type:find("body", 1, true)
		or node_type:find("clause", 1, true)
		or node_type == "chunk"
		or node_type == "program"
		or node_type == "module"
		or node_type == "source_file"
end

-- 结构化的"非表达式"节点：选它们做提取无意义或非法，跳过（继续往上爬）。两类都语义
-- 内聚、闭合（不是开放式噪声黑名单）。集合字面量本身（table/array/object/composite）
-- 不在此列、照常保留；brace-body（go literal_value / rust field_initializer_list）也不在
-- 此列——它在 go 嵌套字面量 {1, 2} 里是合法提取目标，丢了会误伤。
local NON_EXPR_TYPES = {
	-- 实参/形参容器：调用/定义的括号参数列表 (a, b)
	arguments = true,
	argument_list = true,
	parameters = true,
	parameter_list = true,
	formal_parameters = true,
	-- 字面量条目：composite/object/dict 里的 key: value 项（X: a+b 不是独立表达式）
	pair = true, -- js object / python·ruby dict
	keyed_element = true, -- go composite literal
	field_initializer = true, -- rust struct expression
}

-- 节点是否带裸 "=" 子 token（赋值/声明符/默认参数/kwarg）。只看直接子节点，故
-- a == b（"==" token）、a += b（"+=" token）不会误判成赋值。
local function has_assign_token(node)
	for child in node:iter_children() do
		if not child:named() and child:type() == "=" then
			return true
		end
	end
	return false
end

-- 从光标节点向上收集表达式候选，按 range 去重，内→外排序。
local function collect_expr_candidates(node)
	local out, seen = {}, {}
	local cur = node
	while cur do
		local node_type = cur:type()
		if is_stmt_boundary(node_type) then
			break
		end
		if cur:named() and not NON_EXPR_TYPES[node_type] and not has_assign_token(cur) then
			local sr, sc, er, ec = cur:range()
			local key = ("%d:%d:%d:%d"):format(sr, sc, er, ec)
			if not seen[key] then
				seen[key] = true
				out[#out + 1] = cur
			end
		end
		cur = cur:parent()
	end
	return out
end

-- 把 0-based、end 列开区间的 treesitter range 选成 charwise visual（命令式
-- cursor→v→cursor，保证 charwise 且 '< '> marks 正确），供 make_given_range_params
-- 与 gvg@ 复用——和 inline 调度器同一条久经验证的路径。
local function enter_visual_range(sr, sc, er, ec)
	local end_row, end_col = er, ec
	if end_col == 0 then
		-- 区间在行首结束（end 列开区间的边界情况）：退到上一行行尾
		end_row = er - 1
		end_col = #vim.fn.getline(end_row + 1)
	end
	vim.api.nvim_win_set_cursor(0, { sr + 1, sc })
	vim.cmd("normal! v")
	vim.api.nvim_win_set_cursor(0, { end_row + 1, math.max(end_col - 1, 0) })
end

-- <leader>rv 后端：选区已定，refactor.extract → refactoring.nvim extract_var 兜底（gvg@）。
-- 取舍：LSP extract 通常只替换光标处一处；treesitter 兜底替换作用域内所有出现。
local function dispatch_extract(bufnr, sr, sc, er, ec)
	enter_visual_range(sr, sc, er, ec)
	vim.cmd("normal! \27") -- 离开 visual，'< '> 落定到选区

	local make_params = function(b, enc)
		return vim.lsp.util.make_given_range_params(nil, nil, b, enc) --[[@as lsp.CodeActionParams]]
	end

	local reselect = function() vim.cmd("normal! gv") end

	local fallback = function()
		local keys = require("refactoring").extract_var() -- 设 operatorfunc，返回 "g@"
		-- gv 重选刚才的 marks，g@ 在 visual 上触发 extract（即 refactoring 自己的 gvg@）
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("gv" .. keys, true, false, true), "n", false)
	end

	lsp_first_code_action(bufnr, "refactor.extract", make_params, reselect, fallback)
end

-- normal 模式入口：treesitter 选表达式（歧义则弹 picker），预览高亮，再分派。
-- 找不到表达式时报警停（不静默退化成等 motion）。
local function extract_var_smart()
	local bufnr = vim.api.nvim_get_current_buf()
	local node = vim.treesitter.get_node()
	if not node then
		vim.notify("Extract variable: no Tree-sitter node under cursor", vim.log.levels.WARN)
		return
	end

	local candidates = collect_expr_candidates(node)
	if #candidates == 0 then
		vim.notify("Extract variable: no expression under cursor", vim.log.levels.WARN)
		return
	end

	local function proceed(chosen)
		local sr, sc, er, ec = chosen:range()
		-- MVP 预览：高亮选中表达式，3s 自动清；重入时也清。
		vim.api.nvim_buf_clear_namespace(bufnr, extract_preview_ns, 0, -1)
		vim.hl.range(bufnr, extract_preview_ns, "Visual", { sr, sc }, { er, ec }, { inclusive = false, timeout = 3000 })
		dispatch_extract(bufnr, sr, sc, er, ec)
	end

	if #candidates == 1 then
		proceed(candidates[1])
		return
	end

	vim.ui.select(candidates, {
		prompt = "Extract which expression?",
		format_item = function(n)
			local text = vim.treesitter.get_node_text(n, bufnr):gsub("%s+", " ")
			if #text > 60 then
				text = text:sub(1, 57) .. "..."
			end
			return ("%s  [%s]"):format(text, n:type())
		end,
	}, function(chosen)
		if chosen then
			proceed(chosen)
		end
	end)
end

-- inline_var 默认对内联值**无条件**套括号（refactoring.nvim 的 config.lua 里每个
-- group_expression 都是 `("(%s)"):format(...)`），于是 `local x = 5; f(x)` 内联成
-- `f((5))`——括号纯冗余。这里只在值"可能被外层运算符改变结合性"时才套括号。
-- 判定保守且安全：仅当能从字符串形态 100% 确认为单一原子表达式时才去括号，拿不准就
-- 一律保留（宁可多一对，不可改语义）。识别的原子/自界定形态：成对括号 (…)、
-- {…}/[…] 字面量、字符串字面量、标识符·数字·点链·:: 作用域、末尾调用 foo(…)、末尾
-- 下标 a[…]。链式调用 a().b()、负字面量 -5 等不识别 → 保守保留括号（安全，偶尔多余）。
-- 注：走 LSP refactor.inline 那条路不经过这里（LSP 自己不会乱加括号），这里只修
-- refactoring.nvim 兜底路径（lua/python/go 这类没有 LSP inline 的场景）。
local function group_only_if_needed(opts)
	local expr = vim.trim(opts.expression)
	local atomic = expr:match("^%b()$") -- (…)
		or expr:match("^%b{}$") -- {…} 字面量
		or expr:match("^%b[]$") -- […] 字面量
		or expr:match('^"[^"]*"$') -- "…" 字符串
		or expr:match("^'[^']*'$") -- '…' 字符串
		or expr:match("^[%w_%.:]+$") -- 标识符 / 数字 / 点链 / :: 作用域
		or expr:match("^[%w_%.:]+%b()$") -- 末尾调用 foo(…) / a.b.c(…)
		or expr:match("^[%w_%.:]+%b[]$") -- 末尾下标 a[…] / a.b[…]
	if atomic then
		return expr
	end
	return ("(%s)"):format(expr)
end

return {
	"ThePrimeagen/refactoring.nvim",
	-- 新版 refactoring.nvim（master ≥ 2026-05）改用 lewis6991/async.nvim，
	-- 不再依赖 plenary；treesitter 直接走 nvim 0.12+ 内置 vim.treesitter。
	dependencies = { "lewis6991/async.nvim" },
	---@param opts table
	config = function(_, opts)
		-- 模块名冲突消歧（refactoring.nvim issue #521/522/523）：
		--   * lewis6991/async.nvim 在 lua/async.lua 暴露 `M.wrap`（refactoring 用）
		--   * promise-async（nvim-ufo 的依赖）**同样**提供 lua/async.lua，但暴露的是
		--     一个 *可调用 table*（ufo 写 `async(function() ... end)`）
		-- 两者放进 rtp 后 `require("async")` 谁先到看 package.path 顺序，实测
		-- promise-async 胜出 → refactoring.utils:30 `async.wrap(...)` nil。
		--
		-- 不能用 package.preload 永久劫持——会同时打挂 ufo。利用 Lua "每个文件顶部
		-- `local x = require()` 在加载时捕获 upvalue" 的语义：临时把
		-- package.loaded["async"] 换成 lewis6991 的，强制预加载所有 refactoring 内
		-- 用到 async 的文件（它们的 upvalue 一旦捕获就锁定，与后续 package.loaded
		-- 状态无关），最后还原给 ufo 用。
		local prev_async = package.loaded["async"]
		local lewis_path = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "async.nvim", "lua", "async.lua")
		package.loaded["async"] = assert(loadfile(lewis_path))()

		-- refactoring 里全部 `require "async"` 的源文件（grep 结果，2026-05 master）。
		-- 漏一个会在该路径首次被惰性 require 时复发 wrap=nil。新版若新增文件，
		-- 在这里补全。
		local async_consumers = {
			"refactoring",
			"refactoring.utils",
			"refactoring.refactor.extract_func",
			"refactoring.refactor.extract_var",
			"refactoring.refactor.inline_func",
			"refactoring.refactor.inline_var",
			"refactoring.debug.cleanup",
			"refactoring.debug.print_exp",
			"refactoring.debug.print_loc",
			"refactoring.debug.print_var",
		}
		for _, m in ipairs(async_consumers) do
			require(m)
		end

		require("refactoring").setup(opts)

		-- 还原：ufo 的 require("async") 后续命中 cache 仍是 promise-async 的
		package.loaded["async"] = prev_async
	end,
	keys = {
		-- Extract：refactoring.nvim 用 treesitter 给键级粒度（LSP 把 extract method/
		-- variable/to-file 全归 refactor.extract 一个 kind 进菜单，不细分）。
		--
		-- 故意不绑 <leader>rf：IdeaVim 把它给 IntroduceField（用户常用的 IDE 重构），
		-- nvim 这边无对应物——按 parity 原则"无对应物则留空"，避免把它重新挂给
		-- extract_func_to_file 造成同键不同义的肌肉记忆冲突。需要 extract-to-file
		-- 时走 `:Refactor extract_func_to_file`。
		expr_keymap("<leader>rm", "extract_func", "Refactor: Extract function"),
		-- <leader>rv 拆成两个 mode：normal 走智能提取（treesitter 选表达式 + 分派），
		-- visual 保留原行为（expr 返回 g@ 直接对选区生效）。
		{
			"<leader>rv",
			extract_var_smart,
			mode = "n",
			desc = "Refactor: Extract variable (smart)",
		},
		{
			"<leader>rv",
			function() return require("refactoring").extract_var() end,
			mode = "x",
			expr = true,
			desc = "Refactor: Extract variable",
		},
		-- Inline：LSP-first 自动 fallback。<leader>rl 从 lua/core/lsp.lua 搬出来
		-- 由这里统一接管——buffer-local 会盖全局，所以 lsp.lua 那边的同名绑定已删。
		{
			"<leader>rl",
			lsp_inline_then_treesitter,
			mode = { "n", "x" },
			desc = "Refactor: Inline (LSP-first, treesitter fallback)",
		},
	},
	-- 去掉 inline_var 的冗余括号：覆盖 refactoring.nvim 默认那个"无条件套括号"的
	-- group_expression（见 group_only_if_needed）。函数与语言无关，按需要再补语言即可。
	opts = {
		refactor = {
			inline_var = {
				code_generation = {
					group_expression = {
						lua = group_only_if_needed,
						python = group_only_if_needed,
						javascript = group_only_if_needed,
						typescript = group_only_if_needed,
						tsx = group_only_if_needed,
						go = group_only_if_needed,
						c = group_only_if_needed,
					},
				},
			},
		},
	},
}
