-- 侧边文档面板：把 LSP hover 固定成右侧 split，对应 IDEA 的 Documentation 工具窗。
-- 唯一入口是 hover 浮窗可见时按 <C-q>（光标在源码里或已 K 进浮窗都行）：
-- 浮窗内容原样搬进面板，浮窗关掉。IDEA 侧同键，popup 里再按 QuickJavaDoc 即 pin。
--
-- follow=true：面板随 CursorHold 刷新成光标处符号的 hover（IDEA 的
-- Auto-update from source）；拿不到文档时保留旧内容。follow=false（默认）：静态快照。
-- 默认值由 setup() 定，运行时 :DocsPanelFollow 切换。
--
-- 单例：一个 buffer，窗口按当前 tabpage 查找；面板 buffer 被 wipe 即状态归零。
-- 不用 nvim-docs-view：它用全局 client 列表、手拼 URI，且面板自身的 CursorHold
-- 会拿面板 buffer 去请求 hover。
local M = {}

local HOVER = "textDocument/hover"
local api = vim.api

local state = {
	follow = false,
	width = 60,
	buf = nil, ---@type integer?
}

local group = api.nvim_create_augroup("DocsPanel", { clear = true })

---@param win integer
---@return integer? hover 浮窗 id：win 自己就是，或 win 所在 buffer 挂着一个
function M.hover_float(win)
	if vim.w[win][HOVER] then
		return win
	end
	local f = vim.b[api.nvim_win_get_buf(win)].lsp_floating_preview
	if f and api.nvim_win_is_valid(f) and vim.w[f][HOVER] then
		return f
	end
end

---@return integer? 当前 tabpage 里显示面板的窗口
function M.panel_win()
	if not (state.buf and api.nvim_buf_is_valid(state.buf)) then
		return
	end
	local tab = api.nvim_get_current_tabpage()
	for _, w in ipairs(vim.fn.win_findbuf(state.buf)) do
		if api.nvim_win_get_tabpage(w) == tab then
			return w
		end
	end
end

local function ensure_panel()
	if not (state.buf and api.nvim_buf_is_valid(state.buf)) then
		local buf = api.nvim_create_buf(false, true)
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].modifiable = false
		-- edgy 按 ft + 这个标记把它收进右侧 dock（plugins/ui/edgy.lua）
		vim.b[buf].docs_panel = true
		vim.bo[buf].filetype = "markdown"
		pcall(vim.treesitter.start, buf, "markdown")
		api.nvim_create_autocmd("BufWipeout", {
			group = group,
			buffer = buf,
			callback = function() state.buf = nil end,
		})
		state.buf = buf
	end
	local win = M.panel_win()
	if not win then
		win = api.nvim_open_win(state.buf, false, { split = "right", win = -1, width = state.width })
		local wo = vim.wo[win]
		wo.wrap, wo.linebreak, wo.breakindent = true, true, true
		wo.conceallevel, wo.concealcursor = 2, ""
		wo.number, wo.relativenumber, wo.signcolumn, wo.foldenable = false, false, "no", false
		wo.winfixwidth = true
	end
	return state.buf, win
end

---@param lines string[]
local function render(lines)
	local buf, win = ensure_panel()
	vim.bo[buf].modifiable = true
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	api.nvim_win_set_cursor(win, { 1, 0 })
end

---hover 浮窗 → 面板。当前窗口是浮窗时先回到源窗口（与 hover 自己的 `wincmd p` 同路）。
---@param float integer
function M.pin(float)
	local lines = api.nvim_buf_get_lines(api.nvim_win_get_buf(float), 0, -1, false)
	if api.nvim_get_current_win() == float then
		vim.cmd("wincmd p")
	end
	api.nvim_win_close(float, true)
	render(lines)
end

---多 client 合并规则同 vim.lsp.buf.hover：>1 个有内容时加 `# name` 标题。
---@param results table<integer, {err: lsp.ResponseError?, result: lsp.Hover?}>
---@return string[]
function M.merge(results)
	local ids = vim.tbl_keys(results)
	table.sort(ids)
	local parts = {}
	for _, id in ipairs(ids) do
		local r = results[id]
		if not r.err and r.result and r.result.contents then
			local lines = vim.lsp.util.convert_input_to_markdown_lines(r.result.contents)
			if vim.trim(table.concat(lines, "\n")) ~= "" then
				local client = vim.lsp.get_client_by_id(id)
				parts[#parts + 1] = { name = client and client.name or tostring(id), lines = lines }
			end
		end
	end
	local out = {}
	for _, p in ipairs(parts) do
		if #parts > 1 then
			out[#out + 1] = "# " .. p.name
		end
		vim.list_extend(out, p.lines)
	end
	return out
end

local function follow_tick()
	if not M.panel_win() then
		return
	end
	local win, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
	-- 面板自己、浮窗、非文件 buffer 都不是"源码光标"
	if buf == state.buf or vim.bo[buf].buftype ~= "" or api.nvim_win_get_config(win).relative ~= "" then
		return
	end
	if #vim.lsp.get_clients({ bufnr = buf, method = HOVER }) == 0 then
		return
	end
	local pos = api.nvim_win_get_cursor(win)
	vim.lsp.buf_request_all(
		buf,
		HOVER,
		function(client) return vim.lsp.util.make_position_params(win, client.offset_encoding) end,
		function(results)
			-- 慢 server：光标已离开则丢弃
			if not api.nvim_win_is_valid(win) or api.nvim_win_get_buf(win) ~= buf then
				return
			end
			if not vim.deep_equal(api.nvim_win_get_cursor(win), pos) then
				return
			end
			local lines = M.merge(results)
			if #lines > 0 then
				render(lines)
			end
		end
	)
end

---@param on boolean
function M.set_follow(on)
	state.follow = on
	api.nvim_clear_autocmds({ group = group, event = "CursorHold" })
	if on then
		api.nvim_create_autocmd("CursorHold", { group = group, callback = follow_tick })
	end
end

---<C-q> 在源码 buffer 的行为：有 hover 浮窗就 pin，否则回落到原生 <C-q>（= <C-v> 块选）。
function M.pin_or_fallback()
	local float = M.hover_float(api.nvim_get_current_win())
	if float then
		M.pin(float)
	else
		api.nvim_feedkeys(vim.keycode("<C-v>"), "n", false)
	end
end

---@param opts? { follow?: boolean, width?: integer }
function M.setup(opts)
	opts = opts or {}
	if opts.width then
		state.width = opts.width
	end
	M.set_follow(opts.follow == true)
	api.nvim_create_user_command("DocsPanelFollow", function()
		M.set_follow(not state.follow)
		vim.notify("Docs panel follow cursor: " .. (state.follow and "on" or "off"))
	end, { desc = "Toggle docs panel follow-cursor" })
end

return M
