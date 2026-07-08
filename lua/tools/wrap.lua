-- JetBrains SurroundWith / SurroundWithLiveTemplate（<leader>gt / <leader>gT）
-- 的 nvim 实现：visual 选区（或 normal 光标行）→ vim.ui.select 模板菜单 → 包裹。
--
-- 引擎是原生 vim.snippet，刻意不引入 LuaSnip：原生引擎不支持
-- $TM_SELECTED_TEXT（runtime snippet.lua 里显式返回空——"snippets are
-- expanded in insert mode only"），但菜单模式下选区由本模块自己捕获、
-- 转义后拼进模板，snippet 引擎只负责 tabstop 会话，天然接上 blink 的
-- <Tab> 跳转链（plugins/completion/blink.lua）。
--
-- 模板语法 = LSP snippet + 自有记号 $SELECTION$（沿用 live template 的
-- $SELECTION$ 写法）。记号在 vim.snippet.expand 之前被替换掉，不经过
-- snippet parser。块内缩进一律写 \t：expand 会按目标 buffer 的
-- expandtab/shiftwidth 转成实际缩进（注意它转换的是整行所有 \t，选区
-- 字符串里的字面 tab 在 expandtab buffer 中也会被展开——极边缘，接受）。

local M = {}

local TOKEN = "$SELECTION$"

---@class wrap.Template
---@field name string 菜单里显示的名字
---@field body string LSP snippet 语法 + $SELECTION$；不写 $0 时光标终点默认在末尾

-- 按 filetype 组织；加语言 = 加一个 key。JetBrains 出厂自带全语言模板库，
-- 这里只维护实际在用的语言的高频构造。
---@type table<string, wrap.Template[]>
M.templates = {
	go = {
		{ name = "if", body = "if ${1:condition} {\n\t$SELECTION$\n}" },
		{ name = "if / else", body = "if ${1:condition} {\n\t$SELECTION$\n} else {\n\t$2\n}" },
		{ name = "if err := …; err != nil", body = "if err := $SELECTION$; err != nil {\n\t${1:return err}\n}" },
		{ name = "for", body = "for $1 {\n\t$SELECTION$\n}" },
		{ name = "for range", body = "for ${1:_}, ${2:v} := range ${3:items} {\n\t$SELECTION$\n}" },
		{ name = "go func(){ … }()", body = "go func() {\n\t$SELECTION$\n}()" },
		{ name = "defer func(){ … }()", body = "defer func() {\n\t$SELECTION$\n}()" },
	},
	lua = {
		{ name = "if … then", body = "if ${1:condition} then\n\t$SELECTION$\nend" },
		{ name = "if / else", body = "if ${1:condition} then\n\t$SELECTION$\nelse\n\t$2\nend" },
		{ name = "for ipairs", body = "for _, ${1:v} in ipairs(${2:t}) do\n\t$SELECTION$\nend" },
		{ name = "for i = …", body = "for ${1:i} = ${2:1}, ${3:n} do\n\t$SELECTION$\nend" },
		{
			name = "pcall(function() … end)",
			body = "local ${1:ok}, ${2:err} = pcall(function()\n\t$SELECTION$\nend)",
		},
		{ name = "local function", body = "local function ${1:name}()\n\t$SELECTION$\nend" },
		{ name = "do … end", body = "do\n\t$SELECTION$\nend" },
	},
	python = {
		{ name = "if", body = "if ${1:condition}:\n\t$SELECTION$" },
		{ name = "try / except", body = "try:\n\t$SELECTION$\nexcept ${1:Exception} as ${2:e}:\n\t${3:raise}" },
		{ name = "try / finally", body = "try:\n\t$SELECTION$\nfinally:\n\t${1:pass}" },
		{ name = "for", body = "for ${1:item} in ${2:items}:\n\t$SELECTION$" },
		{ name = "with", body = "with ${1:ctx} as ${2:f}:\n\t$SELECTION$" },
		{ name = "def", body = "def ${1:name}():\n\t$SELECTION$" },
	},
	zig = {
		{ name = "if", body = "if (${1:condition}) {\n\t$SELECTION$\n}" },
		{ name = "while", body = "while (${1:condition}) {\n\t$SELECTION$\n}" },
		{ name = "for capture", body = "for (${1:items}) |${2:item}| {\n\t$SELECTION$\n}" },
	},
	rust = {
		{ name = "if", body = "if ${1:condition} {\n\t$SELECTION$\n}" },
		{ name = "if let", body = "if let ${1:Some(v)} = ${2:expr} {\n\t$SELECTION$\n}" },
		{ name = "for", body = "for ${1:item} in ${2:iter} {\n\t$SELECTION$\n}" },
		{ name = "while", body = "while ${1:condition} {\n\t$SELECTION$\n}" },
		{ name = "loop", body = "loop {\n\t$SELECTION$\n}" },
		{ name = "match", body = "match $SELECTION$ {\n\t${1:_} => ${2:todo!()},\n}" },
		{ name = "unsafe", body = "unsafe {\n\t$SELECTION$\n}" },
	},
}

-- 非空行的公共前导空白（逐字节比较，tab/space 混用也只取真正公共的部分）
---@param lines string[]
---@return string
local function common_indent(lines)
	local prefix ---@type string?
	for _, line in ipairs(lines) do
		if line:match("%S") then
			local ws = line:match("^[ \t]*")
			if prefix == nil then
				prefix = ws
			else
				local n = 0
				while n < math.min(#prefix, #ws) and prefix:byte(n + 1) == ws:byte(n + 1) do
					n = n + 1
				end
				prefix = prefix:sub(1, n)
			end
		end
	end
	return prefix or ""
end

-- 选区文本进入 snippet parser 前的转义。\ 和 $ 必须转（$1/${…} 会被解析）；
-- } 是否需要转由文本所处上下文决定，$SELECTION$ 只出现在 text 上下文，
-- 裸 } 在 text 上下文是字面量（friendly-snippets 的 Go 片段全靠这一点），
-- 转了反而会留下字面 \。所以只转 \ 和 $。
---@param text string
---@return string
local function esc(text) return (text:gsub("[\\%$]", "\\%0")) end

-- 把（已 dedent 的）选区行拼进模板：token 所在行的前导空白作为续行缩进。
---@param body string
---@param sel_lines string[]
---@return string
local function render(body, sel_lines)
	local s, e = body:find(TOKEN, 1, true)
	-- 模板是本文件自有数据，记号缺失/多于一个都是编码错误。多记号不能容忍：
	-- render 只替换一处，残留的 $SELECTION$ 会让 snippet parser 解析失败，
	-- 而那时选区已删，失败得很脏（对抗 review finding #3）
	assert(s and not body:find(TOKEN, e + 1, true), "wrap template must contain exactly one " .. TOKEN)
	local pre, post = body:sub(1, s - 1), body:sub(e + 1)
	local hang = pre:match("([^\n]*)$"):match("^[ \t]*")
	local parts = {}
	for i, line in ipairs(sel_lines) do
		-- 空行不垫 hang：垫了就是纯空白行（对抗 review finding #5）
		local prefix = (i > 1 and line:find("%S")) and hang or ""
		parts[i] = prefix .. esc(line)
	end
	return pre .. table.concat(parts, "\n") .. post
end

---@class wrap.Selection
---@field win integer
---@field buf integer
---@field tick integer 采集时的 b:changedtick，回调时校验
---@field linewise boolean
---@field lines string[] 原始选区文本
---@field srow integer 1-based
---@field erow integer 1-based（linewise：含；charwise：末行）
---@field scol integer 1-based 起始字节列（仅 charwise）
---@field ecol_ex integer 0-based 排他终止字节列（仅 charwise）

-- 采集选区。必须在 visual 状态还活着时调用（vim.ui.select 回调是异步的，
-- 届时 mode/'< '> 都不可靠）。blockwise 不支持——JetBrains 侧也没有对应语义。
---@return wrap.Selection?
local function capture()
	local vmode = vim.fn.mode()
	local ctx = {
		win = vim.api.nvim_get_current_win(),
		buf = vim.api.nvim_get_current_buf(),
		tick = vim.b.changedtick,
	}
	if vmode == "n" then
		-- normal 模式：包裹当前行（对应 IDE 里无选区时 surround 当前语句）
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local line = vim.api.nvim_buf_get_lines(0, row - 1, row, true)[1]
		return vim.tbl_extend("error", ctx, { linewise = true, lines = { line }, srow = row, erow = row })
	end
	if vmode ~= "v" and vmode ~= "V" then
		return nil
	end
	local vpos, cpos = vim.fn.getpos("v"), vim.fn.getpos(".")
	local lines = vim.fn.getregion(vpos, cpos, { type = vmode })
	local region = vim.fn.getregionpos(vpos, cpos, { type = vmode })
	local srow, erow = region[1][1][2], region[#region][2][2]
	if vmode == "V" then
		return vim.tbl_extend("error", ctx, { linewise = true, lines = lines, srow = srow, erow = erow })
	end
	local scol = region[1][1][3]
	-- 终止列从选区文本长度反推（字节级，绕开 multibyte 边界数学）
	local ecol_ex = srow == erow and (scol - 1 + #lines[1]) or #lines[#lines]
	return vim.tbl_extend(
		"error",
		ctx,
		{ linewise = false, lines = lines, srow = srow, erow = erow, scol = scol, ecol_ex = ecol_ex }
	)
end

-- 在指定位置展开 snippet。vim.snippet.expand 自己处理模式（normal 也是
-- 一等公民：select_tabstop 按 mode 分支），唯一障碍是 normal 模式光标停
-- 不到 EOL 后一列（插入点在行尾时会被截到前一列）——临时 ve=onemore 解决。
-- 不能用 feedkeys("a","x!") 进 insert：headless/无 TTY 下 insert 循环读
-- stdin 撞 EOF 会直接退出进程。
---@param row integer 1-based
---@param col integer 0-based 字节列（允许 == 行长，即 EOL）
---@param body string
local function expand_at(row, col, body)
	local saved_ve = vim.wo.virtualedit
	vim.wo.virtualedit = "onemore"
	local ok, err = pcall(function()
		vim.api.nvim_win_set_cursor(0, { row, col })
		vim.snippet.expand(body)
	end)
	vim.wo.virtualedit = saved_ve
	if not ok then
		error(err, 0)
	end
end

-- 清掉选区、在插入点展开渲染好的 snippet。
---@param sel wrap.Selection
---@param body string
local function apply(sel, body)
	-- picker 是异步的：挂起期间源窗口可能被关、buffer 可能被 LSP/lint/AI
	-- 插件改写——陈旧行列号写回去会毁错行（对抗 review finding #2/#4），
	-- 任何失配都中止，宁可让用户重来。
	if not vim.api.nvim_win_is_valid(sel.win) then
		vim.notify("wrap: source window closed, aborted", vim.log.levels.WARN)
		return
	end
	vim.api.nvim_set_current_win(sel.win)
	if vim.api.nvim_get_current_buf() ~= sel.buf or vim.b.changedtick ~= sel.tick then
		vim.notify("wrap: buffer changed while picking, aborted", vim.log.levels.WARN)
		return
	end

	local dedented, base ---@type string[], string
	if sel.linewise then
		base = common_indent(sel.lines)
		dedented = {}
		for i, line in ipairs(sel.lines) do
			-- 空行/短行可能不含完整公共前缀，剥不动就整行去空白
			dedented[i] = line:sub(1, #base) == base and line:sub(#base + 1) or line:match("^[ \t]*(.*)$")
		end
	else
		-- charwise：首行从行中开始没有缩进语义；续行去公共缩进，由 hang 重排
		base = ""
		local rest = vim.list_slice(sel.lines, 2)
		local ci = common_indent(rest)
		dedented = { sel.lines[1] }
		for i, line in ipairs(rest) do
			dedented[i + 1] = line:sub(1, #ci) == ci and line:sub(#ci + 1) or line
		end
	end
	local rendered = render(body, dedented)

	local row0 = sel.srow - 1
	if sel.linewise then
		-- 选区行替换成只含缩进的落点行；expand 从它读 base_indent
		vim.api.nvim_buf_set_lines(0, row0, sel.erow, true, { base })
		expand_at(sel.srow, #base, rendered)
	else
		vim.api.nvim_buf_set_text(0, row0, sel.scol - 1, sel.erow - 1, sel.ecol_ex, {})
		expand_at(sel.srow, sel.scol - 1, rendered)
	end
end

-- 包裹构造的判定用结构而非名字后缀（对抗 review finding #1）：
-- `_statement$`/`_declaration$` 会误命中 lua `return {…}`、go 复合字面量
-- / type / var 块、python 多行调用和 docstring 这类光标高频停留的多行
-- 非块节点，剥下去就是毁代码。真正的包裹构造（if/for/try/func/match…）
-- 在 go/lua/python/rust/zig 的语法树里都带"块状"直接子节点：block（含
-- rust match_block）、*_clause（python elif/except/case）、*_case（go
-- switch/select）。分支子句节点自身（elif_clause 等）是构造的一部分而非
-- 构造，命中它会只剥半个构造——显式排除。html/jsx 标签没有块子节点，
-- 按名字放行。
local BLOCK_CHILD_TYPES = { "^block$", "_block$", "_clause$", "_case$" }
local NAME_WRAPPERS = { "^element$", "^jsx_element$" }

---@param node TSNode
---@return boolean
local function is_wrapper(node)
	local t = node:type()
	if t:find("_clause$") then
		return false
	end
	for _, pat in ipairs(NAME_WRAPPERS) do
		if t:find(pat) then
			return true
		end
	end
	for child in node:iter_children() do
		local ct = child:type()
		for _, pat in ipairs(BLOCK_CHILD_TYPES) do
			if ct:find(pat) then
				return true
			end
		end
	end
	return false
end

-- 光标处最近的多行包裹构造节点；根节点不算（顶层语句没有可剥的壳，
-- 不能让 chunk/source_file 兜底成"剥文件第一行"）。
---@return TSNode?
local function wrapper_node(node)
	while node do
		local srow, _, erow = node:range()
		if srow < erow and node:parent() and is_wrapper(node) then
			return node
		end
		node = node:parent()
	end
	return nil
end

-- 缩进语言不走 deleft：它的 python 解析靠 legacy synID 判定关键字
-- （autoload/deleft/python.vim 的 s:skip），treesitter 高亮下 synID 恒空，
-- search 全被跳过 → 返回非空空壳 dict → Run 静默空转（upstream bug）。
-- 这里用 treesitter 节点直接做缩进剥壳，语义 = deleft strategy=none。
local INDENT_UNWRAP_FTS = { python = true }

-- 分支裁决 = 光标位置（和"光标深度选层"同一套心智模型）：光标所在分支
-- 存活，其余分支（except/elif/else…）连头带体删除；finally 恒存活——它在
-- 正常/异常两条控制流上都会执行，丢了就改语义。这对齐 JetBrains：光标在
-- try 体 = "Unwrap try"（丢 handler），光标在 else 体 = "Unwrap else"。
-- 光标停在头部行（try:/if…:）时视同主体分支。多行 clause 头（括号续行）
-- 按单行头处理——极边缘，接受。缩进假设为空格（python 惯例）。
---@param node TSNode
local function indent_unwrap(node)
	local srow, _, erow, ecol = node:range()
	local last = ecol == 0 and erow - 1 or erow -- range 末列为 0 时 erow 是排他行
	local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local header_indent = vim.fn.indent(srow + 1)

	-- 直接子节点里的分支 clause（elif_clause/else_clause/except_clause/finally_clause…）
	---@type { srow: integer, erow: integer, type: string }[]
	local clauses = {}
	for child in node:iter_children() do
		if child:type():find("_clause$") then
			local cs, _, ce, cec = child:range()
			clauses[#clauses + 1] = { srow = cs, erow = cec == 0 and ce - 1 or ce, type = child:type() }
		end
	end
	-- 主体（try 体 / if then 体）：头部行之后到首个 clause 之前
	local main = { srow = srow + 1, erow = clauses[1] and clauses[1].srow - 1 or last, type = "main" }

	local survivor = main
	for _, c in ipairs(clauses) do
		if cursor_row >= c.srow and cursor_row <= c.erow then
			survivor = c
		end
	end

	-- 存活区间（正文行范围）：clause 的首行是它的头（except …:），要剥掉
	---@type { [1]: integer, [2]: integer }[]
	local regions = {}
	local function add(region)
		local from = region.type == "main" and region.srow or region.srow + 1
		if from <= region.erow then
			regions[#regions + 1] = { from, region.erow }
		end
	end
	add(survivor)
	for _, c in ipairs(clauses) do
		if c ~= survivor and c.type == "finally_clause" then
			add(c)
		end
	end
	table.sort(regions, function(a, b) return a[1] < b[1] end)

	local out = {}
	for _, r in ipairs(regions) do
		local lines = vim.api.nvim_buf_get_lines(0, r[1], r[2] + 1, true)
		local body_min
		for i, line in ipairs(lines) do
			if not line:match("^%s*$") then
				body_min = math.min(body_min or math.huge, vim.fn.indent(r[1] + i))
			end
		end
		local shift = (body_min or header_indent) - header_indent
		for _, line in ipairs(lines) do
			out[#out + 1] = line:match("^%s*$") and line or line:sub(shift + 1)
		end
	end
	vim.api.nvim_buf_set_lines(0, srow, last + 1, true, out)
	vim.api.nvim_win_set_cursor(0, { srow + 1, 0 })
end

-- 入口：<leader>gu。deleft 本体的语义是"删除光标所在行的包裹对"——光标
-- 停在正文行时它会把正文行当包裹删掉（危险）。JetBrains 的 Unwrap 是
-- caret 在块内任意位置都作用于外层构造，这里用 treesitter 祖先链补齐：
-- 先跳到包裹行再 :Deleft。没有 parser 的 filetype 回落 deleft 原生语义
-- （光标须停在包裹行）；有 parser 但找不到包裹构造则中止，不做危险回落。
function M.unwrap()
	-- get_parser 在无该语言 parser 时抛错 → pcall 判定"这个 ft 没有 treesitter"
	local has_parser, parser = pcall(vim.treesitter.get_parser)
	if has_parser and parser then
		-- 显式 parse：高亮未启动的 buffer（headless、大文件禁高亮等）树是空的，
		-- get_node 会拿到 nil——不能让它静默滑落到危险的原生语义
		parser:parse()
		local node = vim.treesitter.get_node()
		local wrapper = node and wrapper_node(node)
		if not wrapper then
			vim.notify("unwrap: no enclosing block", vim.log.levels.INFO)
			return
		end
		if INDENT_UNWRAP_FTS[vim.bo.filetype] then
			indent_unwrap(wrapper)
			return
		end
		vim.api.nvim_win_set_cursor(0, { wrapper:range() + 1, 0 })
	end
	vim.cmd("Deleft")
end

-- 入口：<leader>gt / <leader>gT（x + n mode）。
function M.pick()
	local sel = capture()
	if not sel then
		vim.notify("wrap: blockwise selection not supported", vim.log.levels.WARN)
		return
	end
	if vim.fn.mode() ~= "n" then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
	end
	local templates = M.templates[vim.bo.filetype]
	if not templates then
		vim.notify("wrap: no templates for filetype " .. vim.bo.filetype, vim.log.levels.INFO)
		return
	end
	vim.ui.select(templates, {
		prompt = "Surround with",
		format_item = function(item) return item.name end,
	}, function(choice)
		if choice then
			apply(sel, choice.body)
		end
	end)
end

return M
