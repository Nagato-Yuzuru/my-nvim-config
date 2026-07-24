-- PromQL 工具链 presence-check + advisor（**不**安装任何东西）
--
-- 和 tools/scheme_toolchain.lua 同一契约：presence-checker + 一次性 notify 准确的
-- 安装命令。独立成文件而非并进 scheme_toolchain，理由与那份文件拒绝并进
-- mason_ensure 一致——领域不同、探测逻辑不同（scheme 要解析 `raco pkg show`；这里
-- 只探一个 PATH 二进制），强行共表只会制造伪对称。
--
-- 为什么不走 mason_ensure：promql-langserver 不在 mason registry（那里只有规则
-- linter prometheus-pint，命名理由见 mason_ensure.lua 的 TOOL_MAP；这个 LSP 压根
-- 没有）。
-- 它是个 Go 二进制，唯一安装路径是 `go install`——这种写全局 GOBIN 的动作不该在
-- nvim 启动时偷偷跑，所以本模块**只**探测 + 提示，不安装。
--
-- 触发：
--   * core/lsp.lua enable_servers()：enable "promql_ls" 前调 is_installed()，二进制
--     不在就不挂，避免 client 起来又 "quit with exit code 1"。
--   * 打开 promql buffer 时 check_for_ft("promql") notify 一次安装命令（autocmd 注册
--     在 core/lsp.lua，见 register_promql_toolchain_notify）。
-- CI / NO_AUTO_INSTALL 时短路。

local M = {}

local BIN = "promql-langserver"
local HINT = "go install github.com/prometheus-community/promql-langserver/cmd/promql-langserver@latest"

-- executable() 结果一个 session 内稳定，缓存避免每次 enable/FileType 重查。
---@type boolean?
local installed_cache = nil

---@return boolean
function M.is_installed()
	if installed_cache == nil then
		installed_cache = vim.fn.executable(BIN) == 1
	end
	return installed_cache
end

---@type boolean
local notified = false

-- 打开 promql buffer 时提示缺失的 LSP 后端（同一 session 只提示一次）。
---@param ft string
function M.check_for_ft(ft)
	if vim.env.CI == "true" or vim.env.NO_AUTO_INSTALL == "1" then
		return
	end
	if ft ~= "promql" or notified then
		return
	end
	notified = true
	if M.is_installed() then
		return
	end
	vim.notify(
		"[promql] promql-langserver not found — LSP disabled.\n"
			.. "Install for offline syntax diagnostics + function/metric completion:\n  "
			.. HINT,
		vim.log.levels.WARN
	)
end

return M
