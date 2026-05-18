-- GoLand 风格：单返回值类型上敲 `,` → 自动包成 `(T, |)`，光标停在逗号后。
-- 因为 Go 多返回值语法强制要求括号，IDE 替你补上括号才能继续输入第二个类型。
--
-- 命中条件：光标当前节点向上找到 function_declaration / method_declaration /
-- func_literal / function_type 之一，且其 `result` 字段是单一类型（不是
-- parameter_list —— 那种已经括好了），且光标确实落在 result 的字节范围内
-- （避免在 body 里敲 `,` 误触）。

local function unparenthesized_result_at_cursor()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	-- 探光标前一个字节所在的节点。光标在 `string` 末尾时 col 已越过最后一字节，
	-- 直接用 col 探到的会是父节点（function_declaration 自身），漏过 type_identifier。
	local ok, node = pcall(vim.treesitter.get_node, {
		pos = { row - 1, math.max(col - 1, 0) },
		lang = "go",
	})
	if not ok or not node then
		return nil
	end
	while node do
		local t = node:type()
		if t == "function_declaration" or t == "method_declaration" or t == "func_literal" or t == "function_type" then
			local result = node:field("result")[1]
			if not result or result:type() == "parameter_list" then
				return nil
			end
			-- 光标必须真的落在 result 范围里——排除"已经走到 body 里再敲 `,`"。
			local sr, sc, er, ec = result:range()
			local cr, cc = row - 1, col
			local in_range = (cr > sr or (cr == sr and cc >= sc)) and (cr < er or (cr == er and cc <= ec))
			return in_range and result or nil
		end
		node = node:parent()
	end
	return nil
end

vim.keymap.set("i", ",", function()
	local r, c = unpack(vim.api.nvim_win_get_cursor(0))
	local result = unparenthesized_result_at_cursor()
	-- 多行返回值类型（如裸 function_type 跨行）罕见，保守落原 `,`。
	if not result or select(1, result:range()) ~= select(3, result:range()) then
		vim.api.nvim_buf_set_text(0, r - 1, c, r - 1, c, { "," })
		vim.api.nvim_win_set_cursor(0, { r, c + 1 })
		return
	end
	local sr, sc, _, ec = result:range()
	local type_text = vim.api.nvim_buf_get_text(0, sr, sc, sr, ec, {})[1]
	vim.api.nvim_buf_set_text(0, sr, sc, sr, ec, { "(" .. type_text .. ", )" })
	-- 光标落到 `, ` 后面（= 原 sc + len("(") + len(type) + len(", ")）
	vim.api.nvim_win_set_cursor(0, { sr + 1, sc + 1 + #type_text + 2 })
end, { buffer = true, silent = true, desc = "Go: wrap single return in (T, |) on ," })
