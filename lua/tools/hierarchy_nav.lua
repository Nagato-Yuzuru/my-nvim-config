-- gi 只往下、gb 只往上，对齐 IDEA 的 GotoImplementation / GotoSuperMethod。
-- spec: tests/test_hierarchy_nav.lua
--
-- gopls 的 implementation 是双向的：接口上返回实现者，具体类型 / 方法上返回
-- 满足的接口。按符号声明的形态把它拆到 gi / gb；判不出的形态原样交给 gopls。
-- 其它语言 gb 走 typeHierarchy，只覆盖类型；tsc 与 rust-analyzer 不支持
-- typeHierarchy，gb 在 TS / Rust 无结果是预期行为。

local M = {}

---按 Go 声明节点判断符号是抽象（接口 / 接口方法）还是具体。只看名字节点的
---直接父节点：再往上爬会把方法体里的局部变量误判成"具体方法"。
---@param node TSNode? 声明名字处的节点
---@return "abstract"|"concrete"|nil  nil = 判不出，不过滤
function M.classify(node)
	local parent = node and node:parent()
	if not parent then
		return nil
	end
	local kind = parent:type()
	if kind == "method_elem" then
		return "abstract"
	elseif kind == "method_declaration" then
		return "concrete"
	elseif kind == "type_spec" then
		local ty = parent:field("type")[1]
		if not ty then
			return nil
		end
		if ty:type() == "interface_type" then
			return "abstract"
		end
		-- gopls 在函数类型上的 implementation 返回可赋值的函数（向下），不拦
		if ty:type() == "function_type" then
			return nil
		end
		return "concrete"
	end
	return nil
end

---@param loc lsp.Location|lsp.LocationLink
---@param encoding string
---@return "abstract"|"concrete"|nil
local function classify_location(loc, encoding)
	local uri = loc.targetUri or loc.uri
	local range = loc.targetSelectionRange or loc.range
	local bufnr = vim.uri_to_bufnr(uri)
	vim.fn.bufload(bufnr)
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "go")
	if not ok or not parser then
		return nil
	end
	parser:parse()
	local row = range.start.line
	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
	local col = vim.str_byteindex(line, encoding, range.start.character, false)
	return M.classify(vim.treesitter.get_node({ bufnr = bufnr, pos = { row, col }, ignore_injections = true }))
end

---光标符号的形态；无 gopls 时 on_kind 收到 false（= 非 Go，走 LSP 标准语义）。
---@param on_kind fun(kind: "abstract"|"concrete"|false|nil)
local function with_kind(on_kind)
	local bufnr = vim.api.nvim_get_current_buf()
	local client = vim.lsp.get_clients({ bufnr = bufnr, name = "gopls" })[1]
	if not client then
		return on_kind(false)
	end
	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	client:request("textDocument/definition", params, function(err, result)
		local loc = not err and result and (result[1] or (result.uri and result))
		on_kind(loc and classify_location(loc, client.offset_encoding) or nil)
	end, bufnr)
end

function M.implementation()
	with_kind(function(kind)
		if kind == "concrete" then
			vim.notify("No implementations found", vim.log.levels.INFO)
			return
		end
		vim.lsp.buf.implementation()
	end)
end

---Python 的根类隐式继承 object，ty 把它列为 supertype。对每个根类都成立、零信息量，
---IDEA 的 GotoSuper 也不往 object 跳——滤掉。只认 builtins.pyi 里的 object，别的语言不受影响。
---@param items lsp.TypeHierarchyItem[]
---@return lsp.TypeHierarchyItem[]
function M.drop_implicit_supers(items)
	return vim.tbl_filter(
		function(item) return not (item.name == "object" and item.uri:match("/builtins%.pyi$")) end,
		items
	)
end

---自己发 typeHierarchy 请求而不用 vim.lsp.buf.typehierarchy：要过滤结果，且内置 handler
---单结果也开 quickfix（IDEA 是直接跳）。光标处 prepare 出多个 item 时只取第一个。
local function type_supers()
	local bufnr = vim.api.nvim_get_current_buf()
	local client = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/prepareTypeHierarchy" })[1]
	if not client then
		vim.notify("No super found: server lacks typeHierarchy", vim.log.levels.INFO)
		return
	end
	local encoding = client.offset_encoding
	local params = vim.lsp.util.make_position_params(0, encoding)
	client:request("textDocument/prepareTypeHierarchy", params, function(err, prepared)
		if err or not prepared or not prepared[1] then
			vim.notify("No super found", vim.log.levels.INFO)
			return
		end
		client:request("typeHierarchy/supertypes", { item = prepared[1] }, function(err2, result)
			local supers = M.drop_implicit_supers(not err2 and result or {})
			local locations = vim.tbl_map(
				function(item) return { uri = item.uri, range = item.selectionRange } end,
				supers
			)
			if #locations == 0 then
				vim.notify("No super found", vim.log.levels.INFO)
			elseif #locations == 1 then
				vim.lsp.util.show_document(locations[1], encoding, { focus = true })
			else
				local items = vim.lsp.util.locations_to_items(locations, encoding)
				for i, item in ipairs(items) do
					item.text = supers[i].name
				end
				vim.fn.setqflist({}, " ", { title = "Supertypes", items = items })
				vim.cmd("botright copen")
			end
		end, bufnr)
	end, bufnr)
end

function M.super()
	with_kind(function(kind)
		if kind == "concrete" then
			return vim.lsp.buf.implementation()
		end
		type_supers()
	end)
end

return M
