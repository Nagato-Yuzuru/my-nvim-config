-- golangci-lint v2 SuggestedFixes → per-diagnostic code action。
--
-- 背景:golangci-lint 的很多 issue 自带机器可应用的修复(v2 JSON 的
-- Issues[].SuggestedFixes:文件级 byte-offset TextEdits,NewText 为 base64),
-- 但上游 nvim-lint parser 把它整个丢掉;且 nvim-lint 只发诊断、没有 code
-- action 通道 —— vim.lsp.buf.code_action 只聚合 LSP client。
--
-- 跨文件数据流(三段,本模块是枢纽):
--   1. plugins/lint/nvim-lint.lua 把 golangcilint linter 的 parser 指到
--      M.parser:解析时把 SuggestedFixes 换算成 LSP range(0-based、byte 列)
--      + 明文 newText,连同被替换的原文 orig 存进
--      diagnostic.user_data.golangci.fixes。
--   2. lsp/golangci_fix.lua 用 M.server 起 in-process LSP(仅 codeAction
--      能力、无外部进程),由 core/lsp.lua enable。
--   3. codeAction 请求 → M.code_actions 从 vim.diagnostic.get() 捞
--      user_data,校验 orig 仍与 buffer 一致后造 action:
--        quickfix               单条诊断,<leader>ca / <A-CR> 标准入口;
--        source.fixAll.golangci 整 buffer 合并,<leader>ff 的 go 分支定点
--                               调用(plugins/format/conform.lua,与 ruff 的
--                               source.fixAll.ruff 同一形状)。
--
-- 一致性模型:golangci lint 的是**磁盘文件**(InsertLeave 触发时 buffer 可能
-- 已领先磁盘)。TextEdits 的 offset 在 parse 时用磁盘快照换算并抠出 orig;
-- apply 前逐 edit 比对 buffer 当前文本 == orig,不一致就不出这条 action
-- (buffer 保存重 lint 后自然回来),杜绝错位写入。

local M = {}

local severities = {
	error = vim.diagnostic.severity.ERROR,
	warning = vim.diagnostic.severity.WARN,
	refactor = vim.diagnostic.severity.INFO,
	convention = vim.diagnostic.severity.HINT,
}

-- content 每行行首的 0-based byte offset(升序)。文件若以 \n 结尾,末尾会
-- 多出一个"幽灵行"的 start == #content —— 正好让 EOF 处的 range(如
-- whitespace 删尾部空行)也能换算/校验。
local function line_starts(content)
	local starts = { 0 }
	local pos = 1
	while true do
		local nl = content:find("\n", pos, true)
		if not nl then
			break
		end
		starts[#starts + 1] = nl -- '\n' 的 1-based 下标 == 下一行行首的 0-based offset
		pos = nl + 1
	end
	return starts
end

-- 0-based byte offset → 0-based LSP Position(character 为 byte 列;server
-- 声明 positionEncoding=utf-8,client 按字节应用,无需 UTF-16 换算)。
local function offset_to_pos(starts, off)
	local lo, hi = 1, #starts
	while lo < hi do
		local mid = math.ceil((lo + hi) / 2)
		if starts[mid] <= off then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return { line = lo - 1, character = off - starts[lo] }
end

-- 按 range 从 text 里抠原文;starts 必须是同一份 text 的 line_starts。
-- range 越界(行号超出)返回 nil。
local function range_text(text, starts, range)
	local s = starts[range.start.line + 1]
	local e = starts[range["end"].line + 1]
	if not s or not e then
		return nil
	end
	return text:sub(s + range.start.character + 1, e + range["end"].character)
end

-- 单个 SuggestedFix(byte-offset TextEdits)→ { message, edits }。
-- content 是 lint 时的磁盘快照;任一 edit 越界/解码失败则整个 fix 作废
-- (半套 edit 应用出来是坏代码)。NewText 为 null 时是纯删除。
local function convert_fix(sf, content, starts)
	if type(sf.TextEdits) ~= "table" or #sf.TextEdits == 0 then
		return nil
	end
	local edits = {}
	for _, te in ipairs(sf.TextEdits) do
		local s, e = te.Pos, te.End
		if type(s) ~= "number" or type(e) ~= "number" or s < 0 or e < s or e > #content then
			return nil
		end
		local new_text = ""
		if type(te.NewText) == "string" and te.NewText ~= "" then
			local ok, decoded = pcall(vim.base64.decode, te.NewText)
			if not ok then
				return nil
			end
			new_text = decoded
		end
		edits[#edits + 1] = {
			range = { start = offset_to_pos(starts, s), ["end"] = offset_to_pos(starts, e) },
			newText = new_text,
			orig = content:sub(s + 1, e),
		}
	end
	return { message = type(sf.Message) == "string" and sf.Message or "", edits = edits }
end

---nvim-lint parser(挂在 lint.linters.golangcilint.parser)。
---契约:输入为 golangci-lint v2 `--output.json.path=stdout --path-mode=abs`
---的完整 stdout;只保留属于 bufnr 对应文件的 issue;带可用 SuggestedFixes
---的 diagnostic 附 user_data.golangci.fixes(供 M.code_actions 消费)。
---@param output string
---@param bufnr integer
---@param linter_cwd string
---@return vim.Diagnostic[]
function M.parser(output, bufnr, linter_cwd)
	if output == "" then
		return {}
	end
	local ok, decoded = pcall(vim.json.decode, output)
	-- Issues 为 null 时 vim.json 解出 vim.NIL(userdata),一并挡掉
	if not ok or type(decoded) ~= "table" or type(decoded.Issues) ~= "table" then
		return {}
	end

	local curfile = vim.fs.normalize(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p"))

	-- fix 的 byte offset 必须用「lint 读到的那份文件内容」换算行列;惰性读一次
	-- 磁盘快照(无 fix 时零 I/O)。读失败只是丢 fix,诊断照发。
	local content, starts
	local function snapshot()
		if content == nil then
			local f = io.open(curfile, "rb")
			content = f and (f:read("*a") or false) or false
			if f then
				f:close()
			end
			if content then
				starts = line_starts(content)
			end
		end
		return content or nil
	end

	local diagnostics = {}
	for _, item in ipairs(decoded.Issues) do
		-- --path-mode=abs 下 Filename 已是绝对路径;cwd 拼接是对相对路径
		-- 的兜底(沿用上游 adapter 的匹配语义)。
		local fname = vim.fs.normalize(item.Pos.Filename)
		local joined = linter_cwd and vim.fs.normalize(vim.fn.fnamemodify(linter_cwd .. "/" .. item.Pos.Filename, ":p"))
		if curfile == fname or curfile == joined then
			local lnum = math.max((item.Pos.Line or 1) - 1, 0)
			local col = math.max((item.Pos.Column or 1) - 1, 0)
			local diag = {
				lnum = lnum,
				col = col,
				end_lnum = lnum,
				end_col = col,
				severity = severities[item.Severity] or severities.warning,
				source = item.FromLinter,
				message = item.Text,
			}
			if type(item.SuggestedFixes) == "table" and snapshot() then
				local fixes = {}
				for _, sf in ipairs(item.SuggestedFixes) do
					fixes[#fixes + 1] = convert_fix(sf, content, starts)
				end
				if #fixes > 0 then
					diag.user_data = { golangci = { fixes = fixes } }
				end
			end
			diagnostics[#diagnostics + 1] = diag
		end
	end
	return diagnostics
end

-- buffer 当前全文。'eol' 时补尾部 \n,和磁盘字节语义对齐(EOF 处的 fix
-- 校验依赖这一点)。
local function buf_text(bufnr)
	local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
	if vim.bo[bufnr].eol then
		text = text .. "\n"
	end
	return text
end

---buffer 级"一键修全部"的 action kind。命名跟 ruff 的 source.fixAll.ruff 同构,
---<leader>ff 用 only={FIXALL_KIND} + apply=true 定点调用(见 plugins/format/conform.lua);
---带 server 后缀是为了不和 gopls 自己的 source.fixAll 撞车——两家都返回时 client
---会弹选择框而不是直接 apply。
M.FIXALL_KIND = "source.fixAll.golangci"

-- context.only 的层级匹配(LSP 规范:kind 以 . 分层,只给 "source" 也命中
-- "source.fixAll.golangci")。nil = 不筛。
local function kind_wanted(only, kind)
	if only == nil then
		return true
	end
	for _, o in ipairs(only) do
		if kind == o or vim.startswith(kind, o .. ".") then
			return true
		end
	end
	return false
end

local function pos_lt(a, b) return a.line < b.line or (a.line == b.line and a.character < b.character) end

-- 两个 range 是否重叠。相邻(a.end == b.start)不算重叠;两个同点空 range(纯插入)
-- 也不算,LSP 允许同位置多次插入。
local function ranges_overlap(a, b) return pos_lt(a.start, b["end"]) and pos_lt(b.start, a["end"]) end

-- fix 的 edits 剥掉内部字段 orig,只留 client 能吃的 range+newText。
local function public_edits(edits)
	return vim.tbl_map(function(e) return { range = e.range, newText = e.newText } end, edits)
end

---textDocument/codeAction 实现。两种 kind:
---  * quickfix:光标行(或 visual 范围)上每条带 fix 的 golangci 诊断各一条。
---  * source.fixAll.golangci:整 buffer 一条,合并所有仍新鲜的 fix。与 range 无关。
---    每条诊断只取第一个 fix(SuggestedFixes 里多条是互斥备选);按位置排序后
---    与已收 fix 的 range 有重叠的整条丢弃——半套 edit 是坏代码,且 LSP 禁止
---    重叠 edit(gofumpt 的整块格式 fix 常和 staticcheck 的单点 fix 撞同一段)。
---两种都带 edit、client 直接 apply、无 resolve。
---@param params lsp.CodeActionParams
---@return lsp.CodeAction[]
function M.code_actions(params)
	local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
	if not vim.api.nvim_buf_is_loaded(bufnr) then
		return {}
	end
	local only = params.context and params.context.only or nil
	local want_quickfix = kind_wanted(only, "quickfix")
	local want_fixall = kind_wanted(only, M.FIXALL_KIND)
	if not (want_quickfix or want_fixall) then
		return {}
	end
	local uri = params.textDocument.uri
	local first, last = params.range.start.line, params.range["end"].line
	local text = buf_text(bufnr)
	local starts = line_starts(text)

	-- 新鲜 = 每个 edit 的 range 在当前 buffer 上抠出的文本仍等于 lint 时的 orig。
	local function is_fresh(fix)
		for _, edit in ipairs(fix.edits) do
			if range_text(text, starts, edit.range) ~= edit.orig then
				return false
			end
		end
		return true
	end

	local actions = {}
	local fixall_candidates = {} -- 每条诊断第一个新鲜 fix
	for _, diag in ipairs(vim.diagnostic.get(bufnr)) do
		local data = diag.user_data and diag.user_data.golangci
		if data then
			local on_range = diag.lnum <= last and (diag.end_lnum or diag.lnum) >= first
			local first_fresh
			for _, fix in ipairs(data.fixes) do
				if is_fresh(fix) then
					first_fresh = first_fresh or fix
					if want_quickfix and on_range then
						actions[#actions + 1] = {
							title = ("Fix: %s [%s]"):format(
								fix.message ~= "" and fix.message or diag.message,
								diag.source or "golangci"
							),
							kind = "quickfix",
							edit = { changes = { [uri] = public_edits(fix.edits) } },
						}
					end
				end
			end
			if first_fresh then
				fixall_candidates[#fixall_candidates + 1] = first_fresh
			end
		end
	end

	if want_fixall and #fixall_candidates > 0 then
		table.sort(fixall_candidates, function(a, b) return pos_lt(a.edits[1].range.start, b.edits[1].range.start) end)
		local accepted = {} ---@type lsp.Range[]
		local merged = {}
		local n = 0
		for _, fix in ipairs(fixall_candidates) do
			local clash = false
			for _, edit in ipairs(fix.edits) do
				for _, r in ipairs(accepted) do
					if ranges_overlap(edit.range, r) then
						clash = true
						break
					end
				end
				if clash then
					break
				end
			end
			if not clash then
				n = n + 1
				for _, edit in ipairs(fix.edits) do
					accepted[#accepted + 1] = edit.range
					merged[#merged + 1] = { range = edit.range, newText = edit.newText }
				end
			end
		end
		actions[#actions + 1] = {
			title = ("Fix all golangci-lint issues (%d)"):format(n),
			kind = M.FIXALL_KIND,
			edit = { changes = { [uri] = merged } },
		}
	end
	return actions
end

---In-process LSP server(vim.lsp.ClientConfig.cmd 的 function 形式,
---:h vim.lsp.rpc)。只声明 codeActionProvider,kinds 按规范列全(nvim client
---只按 only 过滤结果、不按 kinds 挑 server,列出是给规范和其它 client 看的);
---positionEncoding=utf-8 让 client 按 byte 列应用我们的 range。
---@param dispatchers vim.lsp.rpc.Dispatchers
function M.server(dispatchers)
	local closing = false
	local next_id = 0
	return {
		request = function(method, params, callback)
			next_id = next_id + 1
			if method == "initialize" then
				callback(nil, {
					capabilities = {
						codeActionProvider = { codeActionKinds = { "quickfix", M.FIXALL_KIND } },
						positionEncoding = "utf-8",
					},
					serverInfo = { name = "golangci_fix" },
				})
			elseif method == "textDocument/codeAction" then
				callback(nil, M.code_actions(params))
			elseif method == "shutdown" then
				callback(nil, nil)
			else
				callback(vim.lsp.rpc.rpc_response_error(vim.lsp.protocol.ErrorCodes.MethodNotFound))
			end
			return true, next_id
		end,
		notify = function(method)
			if method == "exit" then
				dispatchers.on_exit(0, 15)
			end
			return true
		end,
		is_closing = function() return closing end,
		terminate = function()
			closing = true
			dispatchers.on_exit(0, 15)
		end,
	}
end

return M
