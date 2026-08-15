-- 语言域：PromQL —— ft + LSP enablement 探测 + 运行时后端配置 + 工具链提示
--（无插件）。filetype / 注入的分工见 lsp/promql_ls.lua 头注释；parser 在
-- plugins/treesitter.lua（install plane）；promql-langserver 不在 mason（Go 二进
-- 制），探测与安装提示的实现在 tools/promql_toolchain.lua。

local registry = require("tools.lang_registry")
registry.register("promql", {
	-- 独立 .promql 文件（少见——yaml 规则里的 PromQL 走注入）：给 promql LSP +
	-- treesitter parser 一个可挂载的 ft。
	ft = { extension = { promql = "promql" } },
	-- 缺失时不挂、不刷 client-quit（同 scheme/swift/tsc）；装好后重启一次 nvim 生效。
	lsp = { promql_ls = { probe = function() return require("tools.promql_toolchain").is_installed() end } },
})

-- 打开 promql buffer 时，若 promql-langserver 缺失则 notify 安装命令（同 scheme
-- 的 scheme_toolchain 提示；本文件顶层随 lazy 的 spec import 在启动早期执行）。
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("UserPromqlToolchain", { clear = true }),
	pattern = "promql",
	callback = function() require("tools.promql_toolchain").check_for_ft("promql") end,
})

-- promql-langserver 运行时改后端 URL（LSP didChangeConfiguration 热配置，无需重启）。
-- server 端 langserver/config.go 期望 params.settings = { promql = { url = ... } }
--（json key promql.url）。这是 env `LANGSERVER_PROMETHEUSURL`（声明式/持久，见
-- lsp/promql_ls.lua 头注释）的命令式补充：session 内即时生效，且记住 URL——之后新
-- attach 的 promql_ls client 自动补推（设一次，全 session 的 .promql 都连上）。
local promql_runtime_url = nil

---@param client vim.lsp.Client
---@param url string
local function promql_push_url(client, url)
	client:notify("workspace/didChangeConfiguration", { settings = { promql = { url = url } } })
end

vim.api.nvim_create_user_command("PromqlUrl", function(opts)
	local url = vim.trim(opts.args)
	if url == "" then
		-- 无参：回显当前已设的 URL（server 不暴露"读"，只能回显我们记住的）。
		vim.notify(
			promql_runtime_url and ("[promql] current backend: " .. promql_runtime_url)
				or "[promql] usage: :PromqlUrl http://host:9090   (no backend set — offline)",
			vim.log.levels.INFO
		)
		return
	end
	promql_runtime_url = url
	local clients = vim.lsp.get_clients({ name = "promql_ls" })
	if #clients == 0 then
		vim.notify(
			"[promql] URL saved but no promql-langserver client attached yet — open a .promql "
				.. "buffer (and install the server); it will be applied on attach.",
			vim.log.levels.WARN
		)
		return
	end
	for _, c in ipairs(clients) do
		promql_push_url(c, url)
	end
	vim.notify(
		("[promql] backend set to %s (%d client%s) — watch for the server's connect result."):format(
			url,
			#clients,
			#clients == 1 and "" or "s"
		),
		vim.log.levels.INFO
	)
end, { nargs = "?", desc = "Set promql-langserver Prometheus backend URL (runtime, hot-reload)" })

-- 新 attach 的 promql_ls 补推已记住的 URL（session-sticky，不必每文件重跑）。
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserPromqlUrlReapply", { clear = true }),
	callback = function(args)
		if not promql_runtime_url then
			return
		end
		local c = vim.lsp.get_client_by_id(args.data.client_id)
		if c and c.name == "promql_ls" then
			promql_push_url(c, promql_runtime_url)
		end
	end,
})

return {}
