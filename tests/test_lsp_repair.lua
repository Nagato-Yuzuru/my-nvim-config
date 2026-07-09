-- core/lsp.lua 的 M.repair_unannotated_edits 边界测试：纯 WorkspaceEdit 表
-- 变换（pyright 孤儿 annotationId 修复，neovim/neovim#34731）。
-- require("core.lsp") 无模块级副作用（setup 是显式调用），headless 可安全加载。

local H = require("tests.helpers")
local child, hooks = H.new_child()

local pre_restart = hooks.pre_case
hooks.pre_case = function()
	pre_restart()
	child.lua([[
		REPAIR = require("core.lsp").repair_unannotated_edits
		R = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 1 } }
	]])
end

local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

T["documentChanges: orphan annotationId is stripped, returns true"] = function()
	child.lua([[
		WE = {
			documentChanges = {
				{
					textDocument = { uri = "file:///x.py", version = 1 },
					edits = {
						{ range = R, newText = "a", annotationId = "orphan" },
						{ range = R, newText = "b" },
					},
				},
			},
		}
		GOT = REPAIR(WE)
	]])
	eq(child.lua_get("GOT"), true)
	eq(child.lua_get("WE.documentChanges[1].edits[1].annotationId == nil"), true)
	eq(child.lua_get("WE.documentChanges[1].edits[1].newText"), "a")
	eq(child.lua_get("WE.documentChanges[1].edits[2].newText"), "b")
end

T["legacy changes map: orphan annotationId is stripped, returns true"] = function()
	child.lua([[
		WE = { changes = { ["file:///x.py"] = { { range = R, newText = "a", annotationId = "orphan" } } } }
		GOT = REPAIR(WE)
	]])
	eq(child.lua_get("GOT"), true)
	eq(child.lua_get([[WE.changes["file:///x.py"][1].annotationId == nil]]), true)
end

T["file-op documentChanges entry (no .edits) is untouched, returns false"] = function()
	child.lua([[
		WE = { documentChanges = { { kind = "rename", oldUri = "file:///a", newUri = "file:///b" } } }
		BEFORE = vim.deepcopy(WE)
		GOT = REPAIR(WE)
	]])
	eq(child.lua_get("GOT"), false)
	eq(child.lua_get("vim.deep_equal(WE, BEFORE)"), true)
end

T["mixed documentChanges: only the edits entry is repaired"] = function()
	child.lua([[
		WE = {
			documentChanges = {
				{ kind = "create", uri = "file:///new" },
				{
					textDocument = { uri = "file:///x.py", version = 1 },
					edits = { { range = R, newText = "a", annotationId = "orphan" } },
				},
			},
		}
		GOT = REPAIR(WE)
	]])
	eq(child.lua_get("GOT"), true)
	eq(child.lua_get("WE.documentChanges[1].kind"), "create")
	eq(child.lua_get("WE.documentChanges[2].edits[1].annotationId == nil"), true)
end

-- 合规服务端（rust-analyzer 等真 annotation）原样放过——修复只针对孤儿 id
T["valid annotationId with matching changeAnnotations is preserved"] = function()
	child.lua([[
		WE = {
			changeAnnotations = { keep = { label = "rename" } },
			documentChanges = {
				{
					textDocument = { uri = "file:///x.py", version = 1 },
					edits = { { range = R, newText = "a", annotationId = "keep" } },
				},
			},
		}
		BEFORE = vim.deepcopy(WE)
		GOT = REPAIR(WE)
	]])
	eq(child.lua_get("GOT"), false)
	eq(child.lua_get("vim.deep_equal(WE, BEFORE)"), true)
end

T["changeAnnotations present but empty: annotationId is an orphan, stripped"] = function()
	child.lua([[
		WE = {
			changeAnnotations = {},
			documentChanges = {
				{
					textDocument = { uri = "file:///x.py", version = 1 },
					edits = { { range = R, newText = "a", annotationId = "orphan" } },
				},
			},
		}
		GOT = REPAIR(WE)
	]])
	eq(child.lua_get("GOT"), true)
	eq(child.lua_get("WE.documentChanges[1].edits[1].annotationId == nil"), true)
end

T["mixed annotations: only orphans stripped, valid ones kept"] = function()
	child.lua([[
		WE = {
			changeAnnotations = { keep = { label = "x" } },
			documentChanges = {
				{
					textDocument = { uri = "file:///x.py", version = 1 },
					edits = {
						{ range = R, newText = "a", annotationId = "keep" },
						{ range = R, newText = "b", annotationId = "orphan" },
					},
				},
			},
		}
		GOT = REPAIR(WE)
	]])
	eq(child.lua_get("GOT"), true)
	eq(child.lua_get("WE.documentChanges[1].edits[1].annotationId"), "keep")
	eq(child.lua_get("WE.documentChanges[1].edits[2].annotationId == nil"), true)
end

T["empty edit / edits without annotationId: false and input unchanged"] = function()
	child.lua([[
		EMPTY = {}
		GOT_EMPTY = REPAIR(EMPTY)
		WE = {
			documentChanges = {
				{ textDocument = { uri = "file:///x.py", version = 1 }, edits = { { range = R, newText = "a" } } },
			},
		}
		BEFORE = vim.deepcopy(WE)
		GOT = REPAIR(WE)
	]])
	eq(child.lua_get("GOT_EMPTY"), false)
	eq(child.lua_get("vim.deep_equal(EMPTY, {})"), true)
	eq(child.lua_get("GOT"), false)
	eq(child.lua_get("vim.deep_equal(WE, BEFORE)"), true)
end

return T
