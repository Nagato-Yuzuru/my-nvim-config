-- Swift 原生调试器：LLVM/Apple 官方 lldb-dap 二进制（随 Swift 工具链，非 Mason）。
--
-- adapter **key 用 "lldb"**（不是 "lldb-dap"）是刻意的互操作选择：
--   1) neotest-swift-testing 的 debug-nearest 硬编码构造 type="lldb" 的 dap 配置
--      （见其 init.lua get_dap_config），复用本文件注册的这一份 adapter；
--   2) nvim-dap 社区惯例也用 dap.adapters.lldb 指代 lldb-dap。
-- 底层 command 仍是 lldb-dap 二进制——key 是逻辑名，跟 codelldb.lua 的
-- type="codelldb" 同理。
--
-- 为什么不复用 dap/codelldb.lua：codelldb 自带的 LLDB **不含 Swift language
-- plugin**，调 Swift 时变量检查 / `po` / 类型还原都退化；工具链的 lldb-dap 内建
-- Swift 支持。故 Swift 专用一份 spec；c/cpp/rust 仍归 codelldb（本文件 filetypes
-- 只列 swift，不抢那三个）。
--
-- lldb-dap 不在裸 PATH（同 swift-format，只有 `xcrun lldb-dap` 可达），故在 dofile
-- （= core/dap.lua 的 setup，nvim-dap 懒加载后才跑）时用 xcrun 解析绝对路径跟随
-- 激活工具链——不是启动期开销。没有 mason 字段 → core/dap.lua 不做 mason 兜底。
--
-- 下面的 Launch/Attach 是**手动调试可执行文件**用（<leader>d*）；测试的
-- debug-nearest（<leader>td）由 neotest-swift-testing 在运行时自建 config，二者
-- 共用这一份 lldb adapter。调试流（纯 SwiftPM）：先 `swift build`（debug）产出
-- .build/debug/<exe>，再 Launch 指向它。build 是独立步骤（overseer / `:!swift build`）。
--
-- exception_breakpoints 刻意不设：lldb-dap 的 Swift 异常 filter 名需从 adapter
-- capabilities 实测确认，写错会让 event_initialized 的默认订阅打空。想要错误断点
-- 用 `<leader>dX` 从 session 实时 filter 列表里选。

---@return string
local function resolve_lldb_dap()
	if vim.fn.executable("lldb-dap") == 1 then
		return "lldb-dap"
	end
	local out = vim.fn.system({ "xcrun", "-f", "lldb-dap" })
	if vim.v.shell_error == 0 and out ~= "" then
		return vim.trim(out)
	end
	return "lldb-dap" -- 兜底：缺失时 session 启动报错（预期，未装 Swift 工具链）
end

---@type DapSpec
return {
	type = "lldb",
	filetypes = { "swift" },
	adapter = {
		type = "executable",
		command = resolve_lldb_dap(),
		name = "lldb",
	},
	configurations = {
		{
			type = "lldb",
			request = "launch",
			name = "Swift: Launch (.build/debug/<exe>)",
			program = function()
				return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/.build/debug/", "file")
			end,
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
			args = {},
		},
		{
			type = "lldb",
			request = "attach",
			name = "Swift: Attach to process",
			pid = function() return require("dap.utils").pick_process() end,
			cwd = "${workspaceFolder}",
		},
	},
}
