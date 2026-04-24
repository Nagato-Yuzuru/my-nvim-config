-- DAP loader：扫描顶层 `dap/*.lua`，把每个 adapter 注入 nvim-dap 的
-- adapters / configurations 表。**镜像 lsp/ 的 per-server 拆分模型**。
--
-- 每个 dap/<name>.lua 必须 return 一个 spec table：
--   {
--     type           = "delve",            -- key in dap.adapters；configs 通过 `type` 字段引用
--     mason          = "delve",            -- 可选：mason 包名（缺省则不自动安装）
--     filetypes      = { "go" },           -- 把 configurations 注册到哪些 ft
--     adapter        = { ... },            -- nvim-dap adapter spec
--     configurations = { ... },            -- list of debug configurations
--   }
--
-- setup() 由 plugins/runtime/dap.lua 在 nvim-dap 加载完后调用，并把收集到的
-- mason 包列表回传给 mason 安装入口。

local M = {}

function M.setup()
	local ok_dap, dap = pcall(require, "dap")
	if not ok_dap then
		vim.notify("core.dap: nvim-dap not available", vim.log.levels.ERROR)
		return {}
	end

	local dap_dir = vim.fn.stdpath("config") .. "/dap"
	local mason_pkgs = {}

	if vim.fn.isdirectory(dap_dir) == 0 then
		return mason_pkgs
	end

	for _, file in ipairs(vim.fn.glob(dap_dir .. "/*.lua", true, true)) do
		local ok, spec = pcall(dofile, file)
		if not ok or type(spec) ~= "table" then
			vim.notify(
				("core.dap: failed to load %s\n%s"):format(file, tostring(spec)),
				vim.log.levels.ERROR
			)
		else
			if spec.type and spec.adapter then
				dap.adapters[spec.type] = spec.adapter
			end
			if spec.configurations and spec.filetypes then
				for _, ft in ipairs(spec.filetypes) do
					dap.configurations[ft] = spec.configurations
				end
			end
			if spec.mason then
				table.insert(mason_pkgs, spec.mason)
			end
		end
	end

	return mason_pkgs
end

-- 通过 mason-registry 直接安装（不依赖 mason-nvim-dap）。所有 mason 装的二进制
-- 都在 ~/.local/share/nvim/mason/bin（mason 启动时已加进 nvim 的 PATH），所以
-- 用 vim.fn.executable() 做 fast-path 判断。
function M.ensure_mason(pkgs)
	if vim.env.CI == "true" or vim.env.NO_AUTO_INSTALL == "1" then
		return
	end
	local ok, mr = pcall(require, "mason-registry")
	if not ok then
		return
	end
	for _, name in ipairs(pkgs) do
		local okp, pkg = pcall(mr.get_package, name)
		if okp and not pkg:is_installed() then
			vim.notify(("Installing %s via Mason…"):format(name), vim.log.levels.INFO)
			pkg:install()
		end
	end
end

return M
