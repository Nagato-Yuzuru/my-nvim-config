-- Mason 自动安装编排——install plane 的 SSOT："哪些 LSP / formatter / linter 二进制
-- 归 Mason 管、缺失时装什么"集中在本文件一眼可查。安装原语在 tools/mason_install.lua；
-- 语言行为事实（ft / 探测式 enable）归 language plane（tools/lang_registry.lua）。
--
-- 安装时机按语言分两档（见 DAILY_FTS）：日常语言的 LSP / formatter / linter 在
-- VeryLazy 时装齐（ensure_daily）；其余首次打开对应 ft 时才装（ensure_for_ft），
-- 按需装好的原生 LSP 自动重新 attach 到已开的 buffer。

---@class LspTool
---@field server string vim.lsp.enable identifier (matches lsp/<server>.lua)
---@field bin string PATH-probe binary name; if executable() == 1 the mason install is skipped
---@field mason string mason-registry package name
---@field external_owner? string when set, vim.lsp.enable will NOT auto-start this server (a non-vim plugin owns its lifecycle)
---@field filetypes? string[] required on external_owner entries: they have no lsp/<server>.lua to read filetypes from, and the install tier is derived from filetypes
---@field verify_cmd? string[] optional liveness probe (e.g. `--version`); if it exits non-zero the bin is treated as missing: mason installs it and the bin name is routed to the mason copy via an override dir at the front of PATH. Needed for rustup proxies that exist on PATH but fail at exec when the matching toolchain component isn't installed.

---@class MasonTool
---@field bin string PATH-probe binary name
---@field mason string mason-registry package name

---@param bin string
---@return boolean
local function has_exec(bin) return vim.fn.executable(bin) == 1 end

-- Run a liveness probe and report whether it exited 0. Output discarded.
-- Used to distinguish a working bin from a broken rustup-proxy symlink.
---@param cmd string[]
---@return boolean
local function probe_ok(cmd)
	local ok, handle = pcall(vim.system, cmd, { text = true }, nil)
	if not ok then
		return false
	end
	return handle:wait(2000).code == 0
end

-- 覆盖目录：只放 verify_cmd 探测失败的 bin → mason/bin/<bin> 软链，排在 PATH 最前。
-- mason 是 append，没有这层的话兜底装的副本会被坏掉的 PATH 条目遮蔽。
-- 软链跨 session 保留，启动早期（VeryLazy 前）打开的 buffer 沿用上次的路由。
local OVERRIDE_DIR = vim.fs.joinpath(vim.fn.stdpath("cache"), "mason-override")

-- 探测前先撤掉该 bin 的覆盖，让 probe 看到真实 PATH；失败才重新链到 mason。
---@param t LspTool|MasonTool
---@return boolean present
local function probe_and_route(t)
	local link = vim.fs.joinpath(OVERRIDE_DIR, t.bin)
	os.remove(link)
	if not has_exec(t.bin) then
		return false
	end
	if not t.verify_cmd or probe_ok(t.verify_cmd) then
		return true
	end
	-- bin 在 PATH 但 probe 失败（rustup proxy 缺 component / mise 空 shim）→ 路由到 mason
	vim.fn.mkdir(OVERRIDE_DIR, "p")
	vim.uv.fs_symlink(vim.fs.joinpath(vim.env.MASON, "bin", t.bin), link)
	return false
end

-- 根据 "name → {bin, mason}" 映射，缺失时自动安装
---@param list string[] tool names to ensure
---@param tool_map table<string, LspTool|MasonTool> name → spec
---@param on_installed? fun(t: LspTool|MasonTool) called once a missing tool finishes installing
local function ensure_tools(list, tool_map, on_installed)
	if vim.env.NO_AUTO_INSTALL == "1" then
		return
	end
	local install_if_missing = require("tools.mason_install").install_if_missing
	for _, name in ipairs(list) do
		local t = tool_map[name]
		if t and not probe_and_route(t) then
			install_if_missing(t.mason, on_installed and function() on_installed(t) end)
		end
	end
end

-- 工具清单 -------------------------------------------------------------------

-- LSP servers：mason 安装清单 + vim.lsp.enable 启用清单的**单一真相**。
--
-- 字段：
--   server        : vim.lsp.enable 用的 server 名（对应 lsp/<server>.lua）
--   bin           : PATH 探测 / executable() 用的二进制名（已在 PATH 时跳过 mason）
--   mason         : mason-registry 包名（缺失时按档自动装：ensure_daily / ensure_for_ft）
--   external_owner: 可选。设了表示该 server 不由 vim.lsp.enable 启动，而是某
--                   外部插件接管启动逻辑（字符串 = 插件名/原因）。core/lsp.lua
--                   过滤这些条目，避免 mason 装好却仍被 vim 原生 enable 误启
--                   ——以及反过来"以为它没装"的两源真相风险。
--   filetypes     : external_owner 条目必填——没有 lsp/<server>.lua 可读，而安装
--                   分档（DAILY_FTS）要靠 filetypes 推出。
--
-- 注意：非 mason 的 LSP（scheme 三件套 / sourcekit / tsc / promql_ls / 进程内
-- golangci_fix）不在本表——它们由语言域经 tools/lang_registry 声明探测式 enable
--（见 plugins/lang/<x>.lua），安装提示归各自工具链模块。
---@type LspTool[]
local LSP_TOOLS = {
	{ server = "lua_ls", bin = "lua-language-server", mason = "lua-language-server" },
	-- Python 类型检查 + LSP 由 ty 接管（见本表 `ty` 条目），不装 pyright：
	-- ty 的 LSP 能力（rename / typeHierarchy / workspaceSymbol / folding …）已覆盖
	-- 我们用到的全部 Python 键位，且 rename 返回合规 TextEdit（pyright 的 rename 会
	-- 触发 annotationId 无 changeAnnotations 的 bug，见 core/lsp.lua 的边界修复 +
	-- neovim/neovim#34731）。两个 type checker 同挂会出双份诊断，故二选一留 ty。
	{ server = "ruff", bin = "ruff", mason = "ruff" },
	{ server = "gopls", bin = "gopls", mason = "gopls" },
	{ server = "jsonls", bin = "vscode-json-language-server", mason = "json-lsp" },
	{ server = "yamlls", bin = "yaml-language-server", mason = "yaml-language-server" },
	{ server = "bashls", bin = "bash-language-server", mason = "bash-language-server" },
	{ server = "taplo", bin = "taplo", mason = "taplo" },
	{ server = "marksman", bin = "marksman", mason = "marksman" },
	{ server = "clangd", bin = "clangd", mason = "clangd" },
	-- OpenTofu-first：LSP 用 tofu-ls（terraform-ls 的 fork），不用 terraform-ls。
	-- tofu-ls 认 terraform/terraform-vars language-id 别名，也原生索引 .tofu 文件，
	-- 且对 OpenTofu 独有语法（encryption 块、provider for_each）不误报。纯 .tf 仓库
	-- 照常工作（它是超集）。配置见 lsp/tofuls.lua。
	{ server = "tofuls", bin = "tofu-ls", mason = "tofu-ls" },
	{ server = "dockerls", bin = "docker-langserver", mason = "dockerfile-language-server" },
	{ server = "just_ls", bin = "just-lsp", mason = "just-lsp" },
	{ server = "denols", bin = "deno", mason = "deno" },
	-- 注意：原生 TS LSP（tsc，见 lsp/tsc.lua）**不在此表**——它由 mise 管的 tsc /
	-- 项目本地二进制提供，无 Mason 稳定包，由语言域 plugins/lang/typescript.lua 探测 enable。
	-- oxlint --lsp：oxc linter，取代 eslint-lsp（见 lsp/oxlint.lua）。诊断 + oxc.fixAll。
	{ server = "oxlint", bin = "oxlint", mason = "oxlint" },
	{ server = "helm_ls", bin = "helm_ls", mason = "helm-ls" },
	{ server = "zls", bin = "zls", mason = "zls" },
	-- rust-analyzer 优先用 rustup component（跟激活 toolchain 同步），mason 兜底安装；
	-- 但 vim.lsp.enable 不启它——rustaceanvim 自己 vim.lsp.start，见 plugins/lang/rust.lua。
	-- verify_cmd: ~/.cargo/bin/rust-analyzer 是 rustup proxy symlink，PATH 探测会
	-- 命中，但激活 toolchain 没装 rust-analyzer component 时 exec 立刻报
	-- "Unknown binary 'rust-analyzer'"。跑一次 --version 把这种"虚假存在"识破，
	-- 让 mason 兜底真正接管。
	{
		server = "rust_analyzer",
		bin = "rust-analyzer",
		mason = "rust-analyzer",
		external_owner = "rustaceanvim",
		filetypes = { "rust" },
		verify_cmd = { "rust-analyzer", "--version" },
	},
	-- tinymist：Typst LSP + 预览后端（typst-preview.nvim 复用同一份二进制）
	{ server = "tinymist", bin = "tinymist", mason = "tinymist" },
	{ server = "ty", bin = "ty", mason = "ty" },
	{ server = "tsp_server", bin = "tsp-server", mason = "tsp-server" },
	-- jq-lsp（wader/jq-lsp，Go）：唯一的 jq LSP——诊断/补全/hover 内置文档/goto-def。
	-- .jq 无 formatter/linter 可接
	{ server = "jq_lsp", bin = "jq-lsp", mason = "jq-lsp" },
	-- awk-language-server（Beaglefoot，npm）：诊断/补全/hover/goto-def。
	{ server = "awk_ls", bin = "awk-language-server", mason = "awk-language-server" },
	-- buf（bufbuild/buf）：`buf lsp serve`，proto 的 LSP+lint+format 一体（见 lsp/buf_ls.lua）。
	-- 优先 mise 管的 buf（项目可钉版本），mason 兜底。verify_cmd：mise shim 在未设
	-- 版本时 PATH 上存在但 exec 报错，同 rust-analyzer 的 rustup proxy 情形。
	{ server = "buf_ls", bin = "buf", mason = "buf", verify_cmd = { "buf", "--version" } },
	-- typos-lsp：跨 ft 拼写检查（见 lsp/typos_lsp.lua）
	{ server = "typos_lsp", bin = "typos-lsp", mason = "typos-lsp" },
}

-- Formatter / Linter binary → Mason 包映射
---@type table<string, MasonTool>
local TOOL_MAP = {
	stylua = { bin = "stylua", mason = "stylua" },
	ruff_format = { bin = "ruff", mason = "ruff" },
	goimports = { bin = "goimports", mason = "goimports" },
	shfmt = { bin = "shfmt", mason = "shfmt" },
	oxfmt = { bin = "oxfmt", mason = "oxfmt" },
	taplo = { bin = "taplo", mason = "taplo" },
	shellcheck = { bin = "shellcheck", mason = "shellcheck" },
	hadolint = { bin = "hadolint", mason = "hadolint" },
	golangcilint = { bin = "golangci-lint", mason = "golangci-lint" },
	yamllint = { bin = "yamllint", mason = "yamllint" },
	actionlint = { bin = "actionlint", mason = "actionlint" },
	typstyle = { bin = "typstyle", mason = "typstyle" },
	tflint = { bin = "tflint", mason = "tflint" },
	-- pint（cloudflare/pint）Prometheus 规则 linter：Mason 包名 prometheus-pint
	-- （裸 `pint` 是 PHP 的 Laravel Pint），装出来的二进制也叫 prometheus-pint，天然
	-- 避开撞名。不进 LINTERS_BY_FT：只对规则文件有意义，内容门控在 plugins/lint/
	-- nvim-lint.lua（同 actionlint），首次命中时经 ensure_tool 兜底安装。
	prometheus_pint = { bin = "prometheus-pint", mason = "prometheus-pint" },
	selene = { bin = "selene", mason = "selene" },
}

-- 非 LSP 工具的**安装意图**（纯 install plane 事实）：打开某 ft 时 Mason 要兜底装上
-- 哪些二进制，不论谁来运行——conform 跑的 formatter，或 LSP 在底层调用的后端（如
-- bashls 的 shellcheck）。nvim-lint 跑的 linter 登记在 LINTERS_BY_FT，自动计入安装，
-- 不在此重复。**不是** runtime 映射——"这个 buffer 跑什么 formatter"由
-- plugins/format/conform.lua 自持（含 go/ts/markdown 的运行时 picker）。本表只留
-- TOOL_MAP 可装的条目（d2/tofu/rustup/mise/scheme 系 formatter 不经 Mason，来路注释
-- 在 conform.lua）。
---@type table<string, string[]>
local TOOL_INSTALLS_BY_FT = {
	lua = { "stylua" },
	python = { "ruff_format" },
	-- goimports 是 conform 的 go picker 的 fallback 分支用的二进制；golangci-lint
	-- 已在 LINTERS_BY_FT 里登记，复用同一个二进制。
	go = { "goimports" },
	-- shellcheck：bashls 的诊断后端（lsp/bashls.lua 的 shellcheckPath），不经 nvim-lint
	sh = { "shfmt", "shellcheck" },
	bash = { "shfmt", "shellcheck" },
	zsh = { "shfmt" },
	json = { "oxfmt" },
	jsonc = { "oxfmt" },
	yaml = { "oxfmt" },
	markdown = { "oxfmt" },
	-- ts/js 的 deno_fmt 分支随 deno 二进制而来（LSP_TOOLS 的 denols 条目管装）
	typescript = { "oxfmt" },
	typescriptreact = { "oxfmt" },
	javascript = { "oxfmt" },
	javascriptreact = { "oxfmt" },
	toml = { "taplo" },
	typst = { "typstyle" },
}

---@type table<string, string[]>
local LINTERS_BY_FT = {
	-- sh/bash: shellcheck 由 bashls 调用，不重复跑（安装意图在 TOOL_INSTALLS_BY_FT）
	dockerfile = { "hadolint" },
	go = { "golangcilint" },
	-- terraform/opentofu: tflint 补 tofu-ls 的 validateOnSave 之外的 provider 层
	-- 检查（不存在的实例类型、废弃语法、未用声明、命名规范）。工具链无关——解析
	-- 同一套 HCL，.tf/.tofu 都覆盖（.tofu 归到 terraform ft，见 core/options.lua）。
	-- 内置 nvim-lint adapter 跑 `tflint --format=json --recursive`，从 nvim cwd 起、
	-- 按相对路径过滤到当前 buffer（故 nvim-lint.lua 不给它加 cwd override，会破坏路径
	-- 匹配）。provider ruleset 需项目里 .tflint.hcl + 手动 `tflint --init`；基础规则免配。
	terraform = { "tflint" },
	-- yamllint 跑风格/缩进/重复 key 检查；schema 校验由 yamlls 负责。
	-- actionlint 只对 .github/workflows/* 有意义（懂 expr / needs / matrix），
	-- 不放在这里自动跑，由 plugins/lint/nvim-lint.lua 里按路径触发。
	yaml = { "yamllint" },
	-- swiftlint 由 mise 提供（不在 TOOL_MAP，不走 Mason）；activation 由
	-- plugins/lint/nvim-lint.lua 按 executable 门控——缺失时不挂，免得每次 lint
	-- 刷 uv.spawn ERROR。装：mise use aqua:realm/SwiftLint
	swift = { "swiftlint" },
	lua = { "selene" },
}

-- 日常档（用户决策 2026-09-30，按语言分档）：这些 ft 的 LSP / formatter / linter 在
-- VeryLazy 时装齐，其余语言首次打开时才装。LSP 归哪档由其 filetypes 与本表是否相交
-- 推出，不逐条标记——新加的语言默认按需。filetypes 为 nil 的 server 挂所有 ft（如
-- typos_lsp），必然日常。promql 在册但无 Mason 工具可装（promql-langserver 走
-- go install，见 tools/promql_toolchain.lua；pint 由 nvim-lint.lua 按内容触发）。
---@type table<string, true>
local DAILY_FTS = {}
for _, ft in ipairs({
	"lua",
	"go",
	"python",
	"markdown",
	"json",
	"jsonc",
	"yaml",
	"toml",
	"sh",
	"bash",
	"zsh",
	"dockerfile",
	"jq",
	"awk",
	"promql",
}) do
	DAILY_FTS[ft] = true
end

-- nil = 挂所有 ft。外部接管的 server 没有 lsp/<server>.lua，filetypes 由条目自带；
-- 两处都没有就当场报错——静默当成"所有 ft"会把它误判进日常档。
---@param t LspTool
---@return string[]?
local function lsp_filetypes(t)
	if t.filetypes then
		return t.filetypes
	end
	local config = vim.lsp.config[t.server]
	if not config then
		error(
			("mason_ensure: no lsp/%s.lua for %q; declare `filetypes` on its LSP_TOOLS entry"):format(
				t.server,
				t.server
			)
		)
	end
	return config.filetypes
end

---@param t LspTool
---@param ft string
---@return boolean
local function lsp_attaches_to(t, ft)
	local fts = lsp_filetypes(t)
	return fts == nil or vim.tbl_contains(fts, ft)
end

---@param t LspTool
---@return boolean
local function lsp_is_daily(t)
	local fts = lsp_filetypes(t)
	return fts == nil or vim.iter(fts):any(function(ft) return DAILY_FTS[ft] ~= nil end)
end

-- 按需装好的 LSP 要补一次 attach：bin 缺失时 vim.lsp.enable 的 FileType 回调已静默
-- 跳过当前 buffer。重复 enable 是幂等的，且会对全部 buffer 重放该回调。外部接管的
-- server 不走这条路，只提示重开。
---@param t LspTool
local function attach_installed(t)
	if t.external_owner then
		vim.notify(("%s installed; :e to let %s start it"):format(t.mason, t.external_owner), vim.log.levels.INFO)
		return
	end
	vim.lsp.enable(t.server)
end

---@param pick fun(t: LspTool): boolean
---@return string[] bins
---@return table<string, LspTool> map bin → entry
local function select_lsp(pick)
	local bins, map = {}, {}
	for _, t in ipairs(LSP_TOOLS) do
		if pick(t) then
			table.insert(bins, t.bin)
			map[t.bin] = t
		end
	end
	return bins, map
end

-- 该组 ft 的非 LSP 工具（TOOL_INSTALLS_BY_FT ∪ LINTERS_BY_FT）的 TOOL_MAP 名，去重
---@param fts string[]
---@return string[]
local function tools_for_fts(fts)
	local seen = {}
	for _, ft in ipairs(fts) do
		for _, name in ipairs(TOOL_INSTALLS_BY_FT[ft] or {}) do
			seen[name] = true
		end
		for _, name in ipairs(LINTERS_BY_FT[ft] or {}) do
			seen[name] = true
		end
	end
	return vim.tbl_keys(seen)
end

local M = {}

-- 把覆盖目录放到 PATH 最前（mason setup 之后调用；幂等）
function M.setup_path()
	local sep = vim.fn.has("win32") == 1 and ";" or ":"
	if not vim.tbl_contains(vim.split(vim.env.PATH or "", sep, { plain = true }), OVERRIDE_DIR) then
		vim.env.PATH = OVERRIDE_DIR .. sep .. (vim.env.PATH or "")
	end
end

-- 装齐日常档：日常语言的 LSP + formatter/linter（VeryLazy 时调用）
function M.ensure_daily()
	ensure_tools(select_lsp(lsp_is_daily))
	ensure_tools(tools_for_fts(vim.tbl_keys(DAILY_FTS)), TOOL_MAP)
end

-- 返回 LSP_TOOLS 中应交给 `vim.lsp.enable` 启动的 server 名列表
-- （即所有未被外部插件接管的条目；rust_analyzer 因 external_owner 被剔除）。
---@return string[]
function M.lsp_servers_for_native_enable()
	local servers = {}
	for _, t in ipairs(LSP_TOOLS) do
		if t.server and not t.external_owner then
			table.insert(servers, t.server)
		end
	end
	return servers
end

-- 打开某 filetype 时按需安装（FileType autocmd 调用）：该 ft 的 formatter/linter，
-- 加上挂在该 ft 上的按需档 LSP（日常档 LSP 归 ensure_daily，这里不重复探测）
---@param ft string
function M.ensure_for_ft(ft)
	ensure_tools(tools_for_fts({ ft }), TOOL_MAP)
	local bins, map = select_lsp(function(t) return not lsp_is_daily(t) and lsp_attaches_to(t, ft) end)
	ensure_tools(bins, map, attach_installed)
end

---@return table<string, string[]>
function M.get_linters_by_ft() return vim.deepcopy(LINTERS_BY_FT) end

-- 按工具名按需安装（供需要"路径触发"的工具使用，如 actionlint 仅在
-- .github/workflows/* 下才想装）
---@param name string TOOL_MAP key
function M.ensure_tool(name) ensure_tools({ name }, TOOL_MAP) end

return M
