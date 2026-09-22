-- lua/tools/golangci_fix.lua 的边界测试：M.parser（golangci-lint v2 JSON →
-- diagnostics + user_data.golangci.fixes）与 M.code_actions（diagnostics →
-- LSP quickfix action）。真实磁盘文件 + 真实 buffer；byte offset 全部手算，
-- offset 二分 / EOF ghost line / multibyte 字节列都经由公开边界间接覆盖。

local H = require("tests.helpers")
local child, hooks = H.new_child()

local pre_restart = hooks.pre_case
hooks.pre_case = function()
	pre_restart()
	child.lua([[
		GF = require("tools.golangci_fix")
		-- 写真实磁盘文件（wb：内容含不含尾部 \n 由 case 自己控制）并 :edit 进 buffer。
		function SETUP_FILE(content)
			PATH = vim.fn.tempname() .. ".go"
			local f = assert(io.open(PATH, "wb"))
			f:write(content)
			f:close()
			vim.cmd.edit(PATH)
			BUF = vim.api.nvim_get_current_buf()
			-- macOS 下 tempname 走 /var → /private/var symlink，buffer 名是解析
			-- 后的路径；fixture 的 Filename 以 buffer 名为准（生产语义：
			-- --path-mode=abs 给出的就是与 buffer 一致的真实路径）。
			PATH = vim.api.nvim_buf_get_name(BUF)
		end
		-- golangci v2 Issue 骨架，over 覆盖字段。
		function ISSUE(over)
			return vim.tbl_deep_extend("force", {
				FromLinter = "whitespace",
				Text = "msg",
				Severity = "warning",
				Pos = { Filename = PATH, Line = 1, Column = 1 },
			}, over or {})
		end
		function PARSE(issues)
			DIAGS = GF.parser(vim.json.encode({ Issues = issues }), BUF, vim.fs.dirname(PATH))
			return DIAGS
		end
		B64 = vim.base64.encode
	]])
end

local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

local function diags_len() return child.lua_get("#DIAGS") end

-- ============================================================ parser：正例
T["parser"] = MiniTest.new_set()

T["parser"]["single-line replacement: exact range/newText/orig"] = function()
	-- content: `x := doIt()\n`，替换 doIt() → run()，byte 5..11（0-based 排他）
	child.lua([[
		SETUP_FILE("x := doIt()\n")
		PARSE({ ISSUE({
			SuggestedFixes = { { Message = "use run", TextEdits = { { Pos = 5, End = 11, NewText = B64("run()") } } } },
		}) })
	]])
	eq(diags_len(), 1)
	eq(child.lua_get("DIAGS[1].lnum"), 0)
	eq(child.lua_get("DIAGS[1].col"), 0)
	eq(child.lua_get("DIAGS[1].severity"), child.lua_get("vim.diagnostic.severity.WARN"))
	eq(child.lua_get("DIAGS[1].source"), "whitespace")
	eq(child.lua_get("DIAGS[1].message"), "msg")
	local fix = child.lua_get("DIAGS[1].user_data.golangci.fixes[1]")
	eq(fix.message, "use run")
	eq(fix.edits, {
		{
			range = { start = { line = 0, character = 5 }, ["end"] = { line = 0, character = 11 } },
			newText = "run()",
			orig = "doIt()",
		},
	})
end

T["parser"]["multi-line replacement spans rows"] = function()
	-- content: `if x {\n\ty()\n}\n`，把 if 块（byte 0..13，不含尾 \n）换成 `y()`
	child.lua([[
		SETUP_FILE("if x {\n\ty()\n}\n")
		PARSE({ ISSUE({
			SuggestedFixes = { { TextEdits = { { Pos = 0, End = 13, NewText = B64("y()") } } } },
		}) })
	]])
	eq(child.lua_get("DIAGS[1].user_data.golangci.fixes[1].edits[1]"), {
		range = { start = { line = 0, character = 0 }, ["end"] = { line = 2, character = 1 } },
		newText = "y()",
		orig = "if x {\n\ty()\n}",
	})
end

T["parser"]["line-start and line-end offsets"] = function()
	-- content: `a\nbb\n`：行首 byte 2（行 1 起点）、行尾 byte 4（bb 之后）
	child.lua([[
		SETUP_FILE("a\nbb\n")
		PARSE({ ISSUE({
			SuggestedFixes = {
				{ TextEdits = { { Pos = 2, End = 2, NewText = B64("x") } } },
				{ TextEdits = { { Pos = 4, End = 4, NewText = B64("y") } } },
			},
		}) })
	]])
	local fixes = child.lua_get("DIAGS[1].user_data.golangci.fixes")
	eq(fixes[1].edits[1].range, { start = { line = 1, character = 0 }, ["end"] = { line = 1, character = 0 } })
	eq(fixes[2].edits[1].range, { start = { line = 1, character = 2 }, ["end"] = { line = 1, character = 2 } })
end

T["parser"]["multibyte: character is byte column, later lines unaffected"] = function()
	-- content: `a := "中"\nb := 2\n`（中 = 3 bytes）
	-- 替换 "中"（byte 5..10）与第二行的 2（byte 16..17）
	child.lua([[
		SETUP_FILE('a := "中"\nb := 2\n')
		PARSE({ ISSUE({
			SuggestedFixes = { {
				TextEdits = {
					{ Pos = 5, End = 10, NewText = B64("name") },
					{ Pos = 16, End = 17, NewText = B64("3") },
				},
			} },
		}) })
	]])
	local edits = child.lua_get("DIAGS[1].user_data.golangci.fixes[1].edits")
	eq(edits[1].range, { start = { line = 0, character = 5 }, ["end"] = { line = 0, character = 10 } })
	eq(edits[1].orig, '"中"')
	eq(edits[2].range, { start = { line = 1, character = 5 }, ["end"] = { line = 1, character = 6 } })
	eq(edits[2].orig, "2")
end

T["parser"]["ghost line: EOF fix on file with trailing newline"] = function()
	-- content: `func f()\n\n`，删掉末尾空行：byte 9..10，end 落在幽灵行 (2,0)
	child.lua([[
		SETUP_FILE("func f()\n\n")
		PARSE({ ISSUE({
			SuggestedFixes = { { TextEdits = { { Pos = 9, End = 10 } } } }, -- NewText 缺失 = 纯删除
		}) })
	]])
	eq(child.lua_get("DIAGS[1].user_data.golangci.fixes[1].edits[1]"), {
		range = { start = { line = 1, character = 0 }, ["end"] = { line = 2, character = 0 } },
		newText = "",
		orig = "\n",
	})
end

T["parser"]["EOF fix on file without trailing newline (End == #content)"] = function()
	child.lua([[
		SETUP_FILE("a = 1")
		PARSE({ ISSUE({
			SuggestedFixes = { { TextEdits = { { Pos = 4, End = 5, NewText = B64("2") } } } },
		}) })
	]])
	eq(child.lua_get("DIAGS[1].user_data.golangci.fixes[1].edits[1]"), {
		range = { start = { line = 0, character = 4 }, ["end"] = { line = 0, character = 5 } },
		newText = "2",
		orig = "1",
	})
end

T["parser"]["fix covering the entire file"] = function()
	child.lua([[
		SETUP_FILE("old\n")
		PARSE({ ISSUE({
			SuggestedFixes = { { TextEdits = { { Pos = 0, End = 4, NewText = B64("new\n") } } } },
		}) })
	]])
	eq(child.lua_get("DIAGS[1].user_data.golangci.fixes[1].edits[1]"), {
		range = { start = { line = 0, character = 0 }, ["end"] = { line = 1, character = 0 } },
		newText = "new\n",
		orig = "old\n",
	})
end

T["parser"]["relative Filename is joined with linter_cwd"] = function()
	child.lua([[
		SETUP_FILE("x\n")
		local rel = vim.fn.fnamemodify(PATH, ":t")
		PARSE({ ISSUE({ Pos = { Filename = rel, Line = 1, Column = 1 } }) })
	]])
	eq(diags_len(), 1)
end

T["parser"]["issues for other files are filtered out"] = function()
	child.lua([[
		SETUP_FILE("x\n")
		PARSE({
			ISSUE({ Pos = { Filename = "/somewhere/else.go", Line = 1, Column = 1 } }),
			ISSUE({}),
		})
	]])
	eq(diags_len(), 1)
end

T["parser"]["unknown severity defaults to WARN"] = function()
	child.lua([[
		SETUP_FILE("x\n")
		PARSE({ ISSUE({ Severity = "bogus" }) })
	]])
	eq(child.lua_get("DIAGS[1].severity"), child.lua_get("vim.diagnostic.severity.WARN"))
end

-- ============================================================ parser：反例
T["parser"]["invalid base64 poisons the whole fix, not half of it"] = function()
	child.lua([[
		SETUP_FILE("x := 1\n")
		PARSE({ ISSUE({
			SuggestedFixes = { { TextEdits = {
				{ Pos = 0, End = 1, NewText = B64("y") },
				{ Pos = 5, End = 6, NewText = "!!!not-base64!!!" },
			} } },
		}) })
	]])
	eq(diags_len(), 1)
	eq(child.lua_get("DIAGS[1].user_data == nil"), true)
end

T["parser"]["out-of-range offsets drop the fix, diagnostic survives"] = function()
	child.lua([[
		SETUP_FILE("ab\n")
		PARSE({ ISSUE({
			SuggestedFixes = {
				{ TextEdits = { { Pos = 0, End = 99, NewText = B64("x") } } }, -- End > #content
				{ TextEdits = { { Pos = -1, End = 1, NewText = B64("x") } } }, -- 负 offset
				{ TextEdits = { { Pos = 2, End = 1, NewText = B64("x") } } }, -- End < Pos
			},
		}) })
	]])
	eq(diags_len(), 1)
	eq(child.lua_get("DIAGS[1].user_data == nil"), true)
end

T["parser"]["empty/garbage/null-Issues output all yield {} without error"] = function()
	child.lua([[SETUP_FILE("x\n")]])
	eq(child.lua_get([[GF.parser("", BUF, "/tmp")]]), {})
	eq(child.lua_get([[GF.parser("not json at all", BUF, "/tmp")]]), {})
	eq(child.lua_get([[GF.parser(vim.json.encode({ Issues = vim.NIL }), BUF, "/tmp")]]), {})
	eq(child.lua_get([[GF.parser(vim.json.encode({}), BUF, "/tmp")]]), {})
end

T["parser"]["issue without usable SuggestedFixes yields plain diagnostic"] = function()
	child.lua([[
		SETUP_FILE("x\n")
		PARSE({
			ISSUE({}),
			ISSUE({ SuggestedFixes = { { TextEdits = {} } } }), -- 空 TextEdits 不算 fix
		})
	]])
	eq(diags_len(), 2)
	eq(child.lua_get("DIAGS[1].user_data == nil and DIAGS[2].user_data == nil"), true)
end

T["parser"]["empty file on disk: zero-length fix at 0 is valid"] = function()
	child.lua([[
		SETUP_FILE("")
		PARSE({ ISSUE({
			SuggestedFixes = { { TextEdits = { { Pos = 0, End = 0, NewText = B64("package main\n") } } } },
		}) })
	]])
	eq(child.lua_get("DIAGS[1].user_data.golangci.fixes[1].edits[1]"), {
		range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
		newText = "package main\n",
		orig = "",
	})
end

-- ============================================================ code_actions
T["code_actions"] = MiniTest.new_set()

-- child 侧公共流程：parse → vim.diagnostic.set → 以 row0 行发起 codeAction 请求。
-- 这一组只看 quickfix，故 only 限定；不带 only 时还会多出一条 fixAll，见 fixAll 组。
local CA_PRELUDE = [[
	NS = vim.api.nvim_create_namespace("golangci_fix_test")
	function REQUEST(row0)
		return GF.code_actions({
			textDocument = { uri = vim.uri_from_bufnr(BUF) },
			range = { start = { line = row0, character = 0 }, ["end"] = { line = row0, character = 0 } },
			context = { diagnostics = {}, only = { "quickfix" } },
		})
	end
]]

T["code_actions"]["fresh diagnostic on cursor line yields quickfix with clean edits"] = function()
	child.lua(CA_PRELUDE)
	child.lua([[
		SETUP_FILE("x := doIt()\n")
		PARSE({ ISSUE({
			SuggestedFixes = { { Message = "use run", TextEdits = { { Pos = 5, End = 11, NewText = B64("run()") } } } },
		}) })
		vim.diagnostic.set(NS, BUF, DIAGS)
		ACTIONS = REQUEST(0)
	]])
	eq(child.lua_get("#ACTIONS"), 1)
	eq(child.lua_get("ACTIONS[1].title"), "Fix: use run [whitespace]")
	eq(child.lua_get("ACTIONS[1].kind"), "quickfix")
	-- 发给 client 的 edit 只含 range+newText（orig 是内部校验字段，不得外泄）
	eq(child.lua_get("ACTIONS[1].edit.changes[vim.uri_from_bufnr(BUF)]"), {
		{
			range = { start = { line = 0, character = 5 }, ["end"] = { line = 0, character = 11 } },
			newText = "run()",
		},
	})
end

-- 新鲜度是逐 edit 按 range 比对 orig（不是全 buffer）：range 内被改 → 撤下
-- action；range 外的改动不影响 fix 的可应用性，action 保留。
T["code_actions"]["stale when buffer changed inside the fix range"] = function()
	child.lua(CA_PRELUDE)
	child.lua([[
		SETUP_FILE("x := doIt()\n")
		PARSE({ ISSUE({
			SuggestedFixes = { { TextEdits = { { Pos = 5, End = 11, NewText = B64("run()") } } } },
		}) })
		vim.diagnostic.set(NS, BUF, DIAGS)
		vim.api.nvim_buf_set_text(0, 0, 7, 0, 8, { "X" }) -- doIt → doXt，命中 fix range
		ACTIONS = REQUEST(0)
	]])
	eq(child.lua_get("ACTIONS"), {})
end

T["code_actions"]["edit outside the fix range keeps the action fresh"] = function()
	child.lua(CA_PRELUDE)
	child.lua([[
		SETUP_FILE("x := doIt()\n")
		PARSE({ ISSUE({
			SuggestedFixes = { { TextEdits = { { Pos = 5, End = 11, NewText = B64("run()") } } } },
		}) })
		vim.diagnostic.set(NS, BUF, DIAGS)
		vim.api.nvim_buf_set_text(0, 0, 0, 0, 1, { "y" }) -- 改第 0 列，fix range 之外
		ACTIONS = REQUEST(0)
	]])
	eq(child.lua_get("#ACTIONS"), 1)
end

T["code_actions"]["diagnostic outside requested range is ignored"] = function()
	child.lua(CA_PRELUDE)
	child.lua([[
		SETUP_FILE("a\nb\nx := doIt()\n")
		PARSE({ ISSUE({
			Pos = { Filename = PATH, Line = 3, Column = 1 },
			SuggestedFixes = { { TextEdits = { { Pos = 9, End = 15, NewText = B64("run()") } } } },
		}) })
		vim.diagnostic.set(NS, BUF, DIAGS)
		MISS = REQUEST(0)
		HIT = REQUEST(2)
	]])
	eq(child.lua_get("MISS"), {})
	eq(child.lua_get("#HIT"), 1)
end

T["code_actions"]["fix message empty falls back to diagnostic message in title"] = function()
	child.lua(CA_PRELUDE)
	child.lua([[
		SETUP_FILE("x := doIt()\n")
		PARSE({ ISSUE({
			Text = "diag says so",
			SuggestedFixes = { { TextEdits = { { Pos = 5, End = 11, NewText = B64("run()") } } } },
		}) })
		vim.diagnostic.set(NS, BUF, DIAGS)
		ACTIONS = REQUEST(0)
	]])
	eq(child.lua_get("ACTIONS[1].title"), "Fix: diag says so [whitespace]")
end

T["code_actions"]["unloaded buffer yields {}"] = function()
	child.lua(CA_PRELUDE)
	eq(
		child.lua_get(
			[[GF.code_actions({ textDocument = { uri = "file:///nonexistent/nope.go" }, range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } } })]]
		),
		{}
	)
end

-- ============================================================ code_actions: source.fixAll.golangci
T["fixAll"] = MiniTest.new_set()

-- 两条诊断各带一个 fix：`x := doIt()\ny := doIt()\n`，第二行 doIt() 在 byte 17..23
local FIXALL_PRELUDE = CA_PRELUDE
	.. [[
	function REQUEST_ONLY(row0, only)
		return GF.code_actions({
			textDocument = { uri = vim.uri_from_bufnr(BUF) },
			range = { start = { line = row0, character = 0 }, ["end"] = { line = row0, character = 0 } },
			context = { diagnostics = {}, only = only },
		})
	end
	function KINDS(actions)
		return vim.tbl_map(function(a) return a.kind end, actions)
	end
	function SETUP_TWO()
		SETUP_FILE("x := doIt()\ny := doIt()\n")
		PARSE({
			ISSUE({ SuggestedFixes = { { TextEdits = { { Pos = 5, End = 11, NewText = B64("run()") } } } } }),
			ISSUE({
				Pos = { Filename = PATH, Line = 2, Column = 1 },
				SuggestedFixes = { { TextEdits = { { Pos = 17, End = 23, NewText = B64("go()") } } } },
			}),
		})
		vim.diagnostic.set(NS, BUF, DIAGS)
	end
]]

T["fixAll"]["merges every fresh fix buffer-wide regardless of cursor range"] = function()
	child.lua(FIXALL_PRELUDE)
	child.lua([[
		SETUP_TWO()
		ACTIONS = REQUEST_ONLY(0, { GF.FIXALL_KIND })
	]])
	eq(child.lua_get("#ACTIONS"), 1)
	eq(child.lua_get("ACTIONS[1].kind"), "source.fixAll.golangci")
	eq(child.lua_get("ACTIONS[1].title"), "Fix all golangci-lint issues (2)")
	eq(child.lua_get("ACTIONS[1].edit.changes[vim.uri_from_bufnr(BUF)]"), {
		{
			range = { start = { line = 0, character = 5 }, ["end"] = { line = 0, character = 11 } },
			newText = "run()",
		},
		{
			range = { start = { line = 1, character = 5 }, ["end"] = { line = 1, character = 11 } },
			newText = "go()",
		},
	})
	-- 应用后两处都换掉 —— 走真实 client 路径（utf-8 byte 列）
	child.lua([[vim.lsp.util.apply_workspace_edit(ACTIONS[1].edit, "utf-8")]])
	eq(child.lua_get("vim.api.nvim_buf_get_lines(BUF, 0, -1, false)"), { "x := run()", "y := go()" })
end

T["fixAll"]["edits are sorted by position even when diagnostics arrive out of order"] = function()
	child.lua(FIXALL_PRELUDE)
	child.lua([[
		SETUP_FILE("x := doIt()\ny := doIt()\n")
		PARSE({
			ISSUE({
				Pos = { Filename = PATH, Line = 2, Column = 1 },
				SuggestedFixes = { { TextEdits = { { Pos = 17, End = 23, NewText = B64("go()") } } } },
			}),
			ISSUE({ SuggestedFixes = { { TextEdits = { { Pos = 5, End = 11, NewText = B64("run()") } } } } }),
		})
		vim.diagnostic.set(NS, BUF, DIAGS)
		EDITS = REQUEST_ONLY(0, { GF.FIXALL_KIND })[1].edit.changes[vim.uri_from_bufnr(BUF)]
	]])
	eq(child.lua_get("EDITS[1].newText"), "run()")
	eq(child.lua_get("EDITS[2].newText"), "go()")
end

T["fixAll"]["overlapping fix is dropped whole, earlier one wins"] = function()
	child.lua(FIXALL_PRELUDE)
	-- fix A 换整行 0..11，fix B 换 5..11：B 与 A 重叠，整条 B 丢弃
	child.lua([[
		SETUP_FILE("x := doIt()\n")
		PARSE({
			ISSUE({ SuggestedFixes = { { TextEdits = { { Pos = 5, End = 11, NewText = B64("run()") } } } } }),
			ISSUE({ SuggestedFixes = { { TextEdits = { { Pos = 0, End = 11, NewText = B64("y := run()") } } } } }),
		})
		vim.diagnostic.set(NS, BUF, DIAGS)
		ACTION = REQUEST_ONLY(0, { GF.FIXALL_KIND })[1]
	]])
	eq(child.lua_get("ACTION.title"), "Fix all golangci-lint issues (1)")
	eq(child.lua_get("#ACTION.edit.changes[vim.uri_from_bufnr(BUF)]"), 1)
	eq(child.lua_get("ACTION.edit.changes[vim.uri_from_bufnr(BUF)][1].newText"), "y := run()")
end

T["fixAll"]["adjacent ranges do not count as overlap"] = function()
	child.lua(FIXALL_PRELUDE)
	-- `ab\n`：删 a（0..1）和删 b（1..2）相邻不相交，两条都保留
	child.lua([[
		SETUP_FILE("ab\n")
		PARSE({
			ISSUE({ SuggestedFixes = { { TextEdits = { { Pos = 0, End = 1 } } } } }),
			ISSUE({ SuggestedFixes = { { TextEdits = { { Pos = 1, End = 2 } } } } }),
		})
		vim.diagnostic.set(NS, BUF, DIAGS)
		ACTION = REQUEST_ONLY(0, { GF.FIXALL_KIND })[1]
	]])
	eq(child.lua_get("ACTION.title"), "Fix all golangci-lint issues (2)")
end

T["fixAll"]["only the first fix of a diagnostic is used (alternatives are exclusive)"] = function()
	child.lua(FIXALL_PRELUDE)
	child.lua([[
		SETUP_FILE("x := doIt()\n")
		PARSE({ ISSUE({ SuggestedFixes = {
			{ TextEdits = { { Pos = 5, End = 11, NewText = B64("run()") } } },
			{ TextEdits = { { Pos = 0, End = 1, NewText = B64("z") } } }, -- 与第一条不重叠，仍不该进 fixAll
		} }) })
		vim.diagnostic.set(NS, BUF, DIAGS)
		ACTION = REQUEST_ONLY(0, { GF.FIXALL_KIND })[1]
	]])
	eq(child.lua_get("ACTION.title"), "Fix all golangci-lint issues (1)")
	eq(child.lua_get("ACTION.edit.changes[vim.uri_from_bufnr(BUF)][1].newText"), "run()")
end

T["fixAll"]["stale fixes are excluded; no fresh fix means no fixAll action"] = function()
	child.lua(FIXALL_PRELUDE)
	child.lua([[
		SETUP_TWO()
		vim.api.nvim_buf_set_text(0, 1, 7, 1, 8, { "X" }) -- 第二行 doIt → doXt
		PARTIAL = REQUEST_ONLY(0, { GF.FIXALL_KIND })
		vim.api.nvim_buf_set_text(0, 0, 7, 0, 8, { "X" }) -- 第一行也脏
		NONE = REQUEST_ONLY(0, { GF.FIXALL_KIND })
	]])
	eq(child.lua_get("PARTIAL[1].title"), "Fix all golangci-lint issues (1)")
	eq(child.lua_get("NONE"), {})
end

T["fixAll"]["context.only filters kinds hierarchically; nil returns both"] = function()
	child.lua(FIXALL_PRELUDE)
	child.lua([[
		SETUP_TWO()
		BOTH = KINDS(REQUEST_ONLY(0, nil))
		QF = KINDS(REQUEST_ONLY(0, { "quickfix" }))
		FA = KINDS(REQUEST_ONLY(0, { "source.fixAll" }))
		SRC = KINDS(REQUEST_ONLY(0, { "source" }))
		NONE = KINDS(REQUEST_ONLY(0, { "refactor" }))
	]])
	-- 光标在第 0 行：quickfix 只出第 0 行那条，fixAll 全 buffer
	eq(child.lua_get("BOTH"), { "quickfix", "source.fixAll.golangci" })
	eq(child.lua_get("QF"), { "quickfix" })
	eq(child.lua_get("FA"), { "source.fixAll.golangci" })
	eq(child.lua_get("SRC"), { "source.fixAll.golangci" })
	eq(child.lua_get("NONE"), {})
end

T["fixAll"]["server advertises both kinds"] = function()
	child.lua([[
		local srv = GF.server({ on_exit = function() end })
		srv.request("initialize", {}, function(_, res) CAPS = res.capabilities end)
	]])
	eq(child.lua_get("CAPS.codeActionProvider.codeActionKinds"), { "quickfix", "source.fixAll.golangci" })
end

return T
