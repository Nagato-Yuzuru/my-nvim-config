-- lua/tools/mason_ensure.lua 的 PATH 路由：verify_cmd 探测失败的 bin 经覆盖目录
-- 路由到 mason 副本，探测通过则 PATH 版本优先。child 内伪造 PATH / MASON /
-- XDG_CACHE_HOME，mason_install 换成记录桩，不碰真实 mason。

local H = require("tests.helpers")
local child, hooks = H.new_child()
local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

-- 搭沙箱：path/buf 按 exit_code 退出，mason/bin/buf 是可用副本
---@param exit_code integer 伪 PATH 上 buf 的退出码
local function setup_sandbox(exit_code)
	child.lua(
		[[
		local exit_code = ...
		local root = vim.fn.tempname()
		local function script(path, code)
			vim.fn.mkdir(vim.fs.dirname(path), "p")
			vim.fn.writefile({ "#!/bin/sh", "exit " .. code }, path)
			vim.fn.setfperm(path, "rwxr-xr-x")
		end
		script(root .. "/path/buf", exit_code)
		script(root .. "/mason/bin/buf", 0)
		vim.env.XDG_CACHE_HOME = root .. "/cache"
		vim.env.MASON = root .. "/mason"
		-- /bin 留给 #!/bin/sh；伪 PATH 上只有 buf，其余 LSP_TOOLS 条目都走"缺失"分支
		vim.env.PATH = root .. "/path:/bin:" .. root .. "/mason/bin"
		_G.installed = {}
		package.loaded["tools.mason_install"] = {
			install_if_missing = function(name) table.insert(_G.installed, name) end,
		}
		_G.root = root
		require("tools.mason_ensure").setup_path()
	]],
		{ exit_code }
	)
end

local function ensure_lsp() child.lua([[require("tools.mason_ensure").ensure_lsp()]]) end

local function exepath_rel() return child.lua_get([[(vim.fn.exepath("buf"):gsub("^" .. vim.pesc(_G.root), ""))]]) end

local function installed_buf() return child.lua_get([[vim.tbl_contains(_G.installed, "buf")]]) end

T["broken PATH bin is routed to the mason copy"] = function()
	setup_sandbox(1)
	ensure_lsp()
	eq(installed_buf(), true)
	eq(exepath_rel(), "/cache/nvim/mason-override/buf")
	eq(child.lua_get([[vim.uv.fs_readlink(vim.fn.exepath("buf"))]]), child.lua_get([[_G.root .. "/mason/bin/buf"]]))
end

T["working PATH bin wins over mason, no install"] = function()
	setup_sandbox(0)
	ensure_lsp()
	eq(installed_buf(), false)
	eq(exepath_rel(), "/path/buf")
end

T["stale override is dropped once the PATH bin works again"] = function()
	setup_sandbox(1)
	ensure_lsp()
	eq(exepath_rel(), "/cache/nvim/mason-override/buf")
	-- 工具链修好了（如 rustup component add）→ 下一轮探测撤掉覆盖
	child.lua([[vim.fn.writefile({ "#!/bin/sh", "exit 0" }, _G.root .. "/path/buf")]])
	ensure_lsp()
	eq(exepath_rel(), "/path/buf")
end

T["setup_path is idempotent"] = function()
	setup_sandbox(0)
	child.lua([[require("tools.mason_ensure").setup_path()]])
	eq(child.lua_get([[select(2, vim.env.PATH:gsub("mason%-override", ""))]]), 1)
end

return T
