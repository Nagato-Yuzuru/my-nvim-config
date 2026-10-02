-- lua/tools/mason_ensure.lua：
--   * PATH 路由——verify_cmd 探测失败的 bin 经覆盖目录路由到 mason 副本，探测通过
--     则 PATH 版本优先；
--   * 安装分档——日常语言 VeryLazy 装齐，其余首次打开 ft 时装，装好后重新 attach。
-- child 内伪造 PATH / MASON / XDG_CACHE_HOME，mason_install 换成记录桩，不碰真实 mason。

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
		-- 环境里带 NO_AUTO_INSTALL=1 时 ensure_tools 会短路、用例空转
		vim.env.NO_AUTO_INSTALL = nil
		-- 伪 PATH 上只有 buf，其余工具都走"缺失"分支；#!/bin/sh 是绝对路径，不需要
		-- /bin 进 PATH——带上它会让宿主机装着的工具（如 shellcheck）漏进探测
		vim.env.PATH = root .. "/path:" .. root .. "/mason/bin"
		_G.installed = {}
		-- 桩同步"装完"并回调，模拟 mason 装好后的 attach 路径
		package.loaded["tools.mason_install"] = {
			install_if_missing = function(name, on_installed)
				table.insert(_G.installed, name)
				if on_installed then
					on_installed()
				end
			end,
		}
		_G.enabled = {}
		vim.lsp.enable = function(name) table.insert(_G.enabled, name) end
		_G.notified = {}
		vim.notify = function(msg) table.insert(_G.notified, msg) end
		_G.root = root
		require("tools.mason_ensure").setup_path()
	]],
		{ exit_code }
	)
end

-- buf_ls 挂 proto，属按需档
local function ensure_proto() child.lua([[require("tools.mason_ensure").ensure_for_ft("proto")]]) end

local function installed() return child.lua_get([[_G.installed]]) end

local function exepath_rel() return child.lua_get([[(vim.fn.exepath("buf"):gsub("^" .. vim.pesc(_G.root), ""))]]) end

local function installed_buf() return child.lua_get([[vim.tbl_contains(_G.installed, "buf")]]) end

T["broken PATH bin is routed to the mason copy"] = function()
	setup_sandbox(1)
	ensure_proto()
	eq(installed_buf(), true)
	eq(exepath_rel(), "/cache/nvim/mason-override/buf")
	eq(child.lua_get([[vim.uv.fs_readlink(vim.fn.exepath("buf"))]]), child.lua_get([[_G.root .. "/mason/bin/buf"]]))
end

T["working PATH bin wins over mason, no install"] = function()
	setup_sandbox(0)
	ensure_proto()
	eq(installed_buf(), false)
	eq(exepath_rel(), "/path/buf")
end

T["stale override is dropped once the PATH bin works again"] = function()
	setup_sandbox(1)
	ensure_proto()
	eq(exepath_rel(), "/cache/nvim/mason-override/buf")
	-- 工具链修好了（如 rustup component add）→ 下一轮探测撤掉覆盖
	child.lua([[vim.fn.writefile({ "#!/bin/sh", "exit 0" }, _G.root .. "/path/buf")]])
	ensure_proto()
	eq(exepath_rel(), "/path/buf")
end

T["setup_path is idempotent"] = function()
	setup_sandbox(0)
	child.lua([[require("tools.mason_ensure").setup_path()]])
	eq(child.lua_get([[select(2, vim.env.PATH:gsub("mason%-override", ""))]]), 1)
end

T["daily tier installs daily-language toolchains only"] = function()
	setup_sandbox(0)
	child.lua([[require("tools.mason_ensure").ensure_daily()]])
	local got = installed()
	-- typos-lsp：filetypes 为 nil（挂所有 ft）→ 必然日常
	-- shellcheck：LSP 后端（bashls 调用），经 TOOL_INSTALLS_BY_FT 计入安装
	for _, pkg in ipairs({
		"lua-language-server",
		"gopls",
		"ty",
		"typos-lsp",
		"jq-lsp",
		"stylua",
		"golangci-lint",
		"shellcheck",
	}) do
		eq(vim.tbl_contains(got, pkg), true)
	end
	for _, pkg in ipairs({ "zls", "clangd", "rust-analyzer", "tinymist", "typstyle", "buf" }) do
		eq(vim.tbl_contains(got, pkg), false)
	end
end

T["on-demand LSP installs on first open and re-attaches"] = function()
	setup_sandbox(0)
	child.lua([[require("tools.mason_ensure").ensure_for_ft("zig")]])
	eq(installed(), { "zls" })
	eq(child.lua_get([[_G.enabled]]), { "zls" })
end

T["daily LSPs are not re-probed on FileType"] = function()
	setup_sandbox(0)
	child.lua([[require("tools.mason_ensure").ensure_for_ft("lua")]])
	-- lua_ls / typos_lsp 归 ensure_daily；这里只装 lua 的 formatter/linter
	eq(vim.tbl_contains(installed(), "lua-language-server"), false)
	eq(vim.tbl_contains(installed(), "typos-lsp"), false)
	eq(vim.tbl_contains(installed(), "stylua"), true)
end

T["external-owner LSP installs by declared filetypes, notifies instead of enabling"] = function()
	setup_sandbox(0)
	child.lua([[require("tools.mason_ensure").ensure_for_ft("rust")]])
	eq(installed(), { "rust-analyzer" })
	eq(child.lua_get([[_G.enabled]]), {})
	eq(child.lua_get([[_G.notified[1]:find("rustaceanvim", 1, true) ~= nil]]), true)
end

return T
