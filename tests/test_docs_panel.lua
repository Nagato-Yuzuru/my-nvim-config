-- lua/tools/docs_panel.lua：真实 hover 浮窗 + 进程内假 LSP，零 mock。

local H = require("tests.helpers")
local child, hooks = H.new_child()

local pre_restart = hooks.pre_case
hooks.pre_case = function()
	pre_restart()
	child.lua([[
		DP = require("tools.docs_panel")
		DP.setup()
		-- 按行返回 hover 文本：第 1 行 alpha，第 2 行 beta，第 3 行无文档
		DOCS = { "alpha doc", "beta doc", nil }
		local function server(dispatchers)
			return {
				request = function(method, params, callback)
					if method == "initialize" then
						callback(nil, { capabilities = { hoverProvider = true, positionEncoding = "utf-8" } })
					elseif method == "textDocument/hover" then
						local d = DOCS[params.position.line + 1]
						callback(nil, d and { contents = { kind = "markdown", value = d } } or nil)
					else
						callback(nil, nil)
					end
					return true, 1
				end,
				notify = function() return true end,
				is_closing = function() return false end,
				terminate = function() end,
			}
		end
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta", "gamma" })
		vim.lsp.start({ name = "fake", cmd = server, root_dir = vim.fn.getcwd() })
		vim.wait(1000, function() return #vim.lsp.get_clients({ bufnr = 0 }) > 0 end)
		SRC = vim.api.nvim_get_current_win()
		function HOVER()
			vim.lsp.buf.hover()
			vim.wait(1000, function() return DP.hover_float(SRC) ~= nil end)
			return DP.hover_float(SRC)
		end
		function PANEL_TEXT()
			local w = DP.panel_win()
			return w and table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false), "\n")
		end
	]])
end

local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

T["pin from source window moves hover into panel and keeps focus"] = function()
	child.lua([[FLOAT = HOVER(); DP.pin(FLOAT)]])
	eq(child.lua_get("vim.api.nvim_win_is_valid(FLOAT)"), false)
	eq(child.lua_get("PANEL_TEXT()"), "alpha doc")
	eq(child.lua_get("vim.api.nvim_get_current_win() == SRC"), true)
	eq(child.lua_get("vim.bo[vim.api.nvim_win_get_buf(DP.panel_win())].modifiable"), false)
end

T["pin from inside the float returns focus to source"] = function()
	child.lua([[FLOAT = HOVER(); vim.api.nvim_set_current_win(FLOAT); DP.pin(FLOAT)]])
	eq(child.lua_get("vim.api.nvim_get_current_win() == SRC"), true)
	eq(child.lua_get("PANEL_TEXT()"), "alpha doc")
end

T["<C-q> in source without hover falls back to blockwise visual"] = function()
	child.lua([[DP.pin_or_fallback()]])
	child.type_keys("") -- 让 feedkeys 落地
	eq(child.fn.mode(), "\22")
	eq(child.lua_get("DP.panel_win()"), vim.NIL)
end

T["follow updates on CursorHold and keeps old content when no docs"] = function()
	child.lua([[
		DP.set_follow(true)
		DP.pin(HOVER())
		vim.api.nvim_win_set_cursor(SRC, { 2, 0 })
		vim.api.nvim_exec_autocmds("CursorHold", {})
		vim.wait(1000, function() return PANEL_TEXT() == "beta doc" end)
	]])
	eq(child.lua_get("PANEL_TEXT()"), "beta doc")
	child.lua([[
		vim.api.nvim_win_set_cursor(SRC, { 3, 0 })
		vim.api.nvim_exec_autocmds("CursorHold", {})
		vim.wait(100)
	]])
	eq(child.lua_get("PANEL_TEXT()"), "beta doc")
end

T["follow=false keeps a static snapshot"] = function()
	child.lua([[
		-- 默认 follow=false
		DP.pin(HOVER())
		vim.api.nvim_win_set_cursor(SRC, { 2, 0 })
		vim.api.nvim_exec_autocmds("CursorHold", {})
		vim.wait(100)
	]])
	eq(child.lua_get("PANEL_TEXT()"), "alpha doc")
end

T["re-pin reuses the panel window"] = function()
	child.lua([[
		DP.pin(HOVER())
		PW = DP.panel_win()
		vim.api.nvim_win_set_cursor(SRC, { 2, 0 })
		DP.pin(HOVER())
	]])
	eq(child.lua_get("DP.panel_win() == PW"), true)
	eq(child.lua_get("PANEL_TEXT()"), "beta doc")
	eq(child.lua_get("#vim.api.nvim_tabpage_list_wins(0)"), 2)
end

T["merge titles each client only when several answer"] = function()
	eq(
		child.lua_get([[DP.merge({ [1] = { result = { contents = "only" } }, [2] = { result = { contents = "" } } })]]),
		{ "only" }
	)
end

return T
