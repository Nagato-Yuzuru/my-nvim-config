-- Treesitter 选择的自写逻辑,从 plugins/edit/textobjects.lua 的 config 闭包
-- 提出的 tested seam(spec: tests/test_ts_select.lua)。两块同源但独立:
--   * select_or_abort —— textobject 无命中时中止 operator(26c075d 修的真 bug,
--     feedkeys typeahead 技巧);
--   * 增量选区 —— <A-w>/<A-W> 按语法树逐级扩/缩,per-buffer 栈。
-- 键位接线留在 plugins/edit/textobjects.lua。本模块不 require 任何插件:
-- select 函数由接线处注入,"无命中 ⇒ 静默返回、不动 mode" 的上游语义任何
-- 同形函数都能模拟,测试因此无需加载 nvim-treesitter-textobjects。

local M = {}

-- 无匹配时 select.select_textobject() 静默返回(上游行为,见 select.lua 的
-- `if range6 then`)。visual 里无害,但 operator-pending 里算子会落在光标处
-- 的零宽区间:`dal` 只是空操作,`ysal(` 却会就地插入一对空 `()` 污染 buffer,
-- `cal` 会莫名进插入模式。内建文本对象(`i(`)无匹配时由 Vim 直接中止算子
-- ——这里补齐同样的语义:无匹配 ⇒ 仍停在 operator-pending(mode 前缀 "no"),
-- 据此喂 <Esc> 撤掉算子。
--
-- feedkeys 必须带 "i"(插到 typeahead 队首):默认的追加语义会让 <Esc> 排在
-- 算子结算之后才被读到,`ys` 的 operatorfunc 早已跑完(实测 `ysal(` 仍插入
-- 空 `()`)。"x"(立即执行)则会把人卡在 operator-pending。
---@param select_fn fun(query: string)  select.select_textobject 的形状
---@param query string  capture,如 "@function.outer"
---@return fun()  可直接绑 {"x","o"} 键位的闭包
function M.select_or_abort(select_fn, query)
	return function()
		select_fn(query)
		if vim.api.nvim_get_mode().mode:sub(1, 2) == "no" then
			vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "ni", false)
		end
	end
end

-- ===== 增量选区 =====
-- 栈在下次从 normal 按 <A-w> 时重置,移动光标后重新扩张总是从头开始。
-- per-buffer 键控不是摆设:A buffer 里 Esc 掉的栈仍在,B buffer 里扩张不会
-- 覆盖它,gv 回 A 后还能从原节点继续扩——全局单栈会拿着 B 的节点在 A 里选区。
local sel_stack = {}

-- 向上找 range 严格更大的祖先。grammar 包装节点(expression、
-- assignment_expression 等)常与子节点同 range,会让 <A-w> 看起来没反应。
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
		-- 节点结束在下一行 0 列(如根节点吃掉末尾换行):贴齐到上一行行尾。
		e_line = erow
		local line = vim.api.nvim_buf_get_lines(0, erow - 1, erow, false)[1] or ""
		e_col = math.max(#line, 1)
	else
		e_line, e_col = erow + 1, ecol
	end

	local mode = vim.api.nvim_get_mode().mode
	if mode == "v" then
		-- 已在 charwise visual:不离开 visual、两端都重定位。不这样做的话
		-- anchor 会钉在最初按 `v` 的位置,扩张只朝一个方向长。
		vim.fn.setpos(".", { 0, e_line, e_col, 0 }) -- cursor → 新终点
		vim.cmd("normal! o") -- 翻转:anchor ↔ cursor
		vim.fn.setpos(".", { 0, s_line, s_col, 0 }) -- cursor → 新起点
	else
		-- 丢掉非 charwise 的 visual,重新以 charwise 进入。
		if mode == "V" or mode == "\22" then
			vim.cmd("normal! \27")
		end
		vim.fn.setpos(".", { 0, s_line, s_col, 0 })
		vim.cmd("normal! v")
		vim.fn.setpos(".", { 0, e_line, e_col, 0 })
	end
end

function M.expand()
	local buf = vim.api.nvim_get_current_buf()
	-- 从 normal 起手永远重开一个栈。
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

function M.shrink()
	local buf = vim.api.nvim_get_current_buf()
	local stack = sel_stack[buf]
	if not stack or #stack <= 1 then
		return
	end
	stack[#stack] = nil
	select_node(stack[#stack])
end

return M
