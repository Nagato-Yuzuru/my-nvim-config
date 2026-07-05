-- Mason 安装原语：装一个 mason 包（若尚未安装）。
--
-- LSP 侧（tools/mason_ensure.lua 的 ensure_tools）与 DAP 侧（core/dap.lua 的
-- ensure_mason）共用这份"缺失即装"逻辑（单一真相）。
--
-- 责任边界：**不**在此处理 CI=true / NO_AUTO_INSTALL=1 跳过，也**不**做 PATH
-- 存在性探测——这两件事各 caller 语义不同（LSP 侧在 ensure_tools 里跳 CI 并用
-- has_exec/probe_ok 探 PATH；DAP 侧在 ensure_mason 里跳 CI 并按 adapter bin 探
-- PATH），留在各自 caller。此处只认"包名 → 装/不装"这一层。
local M = {}

---@param name string mason-registry 包名
function M.install_if_missing(name)
	local ok, mr = pcall(require, "mason-registry")
	if not ok then
		return
	end
	local okp, pkg = pcall(mr.get_package, name)
	if not okp then
		return
	end
	if pkg:is_installed() then
		return
	end
	-- pkg:install() 内部 assert(not is_installing())，autocmd（BufNewFile +
	-- FileType）短时间二次触发会撞上正在装的同一个包，这里手动短路。
	if pkg.is_installing and pkg:is_installing() then
		return
	end
	vim.notify(("Installing %s via Mason…"):format(name), vim.log.levels.INFO)
	pkg:install()
end

return M
