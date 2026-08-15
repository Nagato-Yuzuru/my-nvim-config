-- Mason 自动安装编排——install plane 的 SSOT："哪些 LSP / formatter / linter 二进制
-- 归 Mason 管、缺失时装什么"集中在本文件一眼可查。安装原语在 tools/mason_install.lua；
-- 语言行为事实（ft / 探测式 enable）归 language plane（tools/lang_registry.lua）。

---@class LspTool
---@field server string vim.lsp.enable identifier (matches lsp/<server>.lua)
---@field bin string PATH-probe binary name; if executable() == 1 the mason install is skipped
---@field mason string mason-registry package name
---@field external_owner? string when set, vim.lsp.enable will NOT auto-start this server (a non-vim plugin owns its lifecycle)
---@field verify_cmd? string[] optional liveness probe (e.g. `--version`); if it exits non-zero the bin is treated as missing and mason fallback kicks in. Needed for rustup proxies that exist on PATH but fail at exec when the matching toolchain component isn't installed.

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

-- 根据 "name → {bin, mason}" 映射，缺失时自动安装
---@param list string[] tool names to ensure
---@param tool_map table<string, MasonTool> name → spec
local function ensure_tools(list, tool_map)
	if vim.env.CI == "true" or vim.env.NO_AUTO_INSTALL == "1" then
		return
	end
	local install_if_missing = require("tools.mason_install").install_if_missing
	for _, name in ipairs(list) do
		local t = tool_map[name]
		if t then
			local present = has_exec(t.bin)
			if present and t.verify_cmd and not probe_ok(t.verify_cmd) then
				-- bin on PATH but probe fails (typical: rustup proxy without component) → fall through to mason
				present = false
			end
			if not present then
				install_if_missing(t.mason)
			end
		end
	end
end

-- 工具清单 -------------------------------------------------------------------

-- LSP servers：mason 安装清单 + vim.lsp.enable 启用清单的**单一真相**。
--
-- 字段：
--   server        : vim.lsp.enable 用的 server 名（对应 lsp/<server>.lua）
--   bin           : PATH 探测 / executable() 用的二进制名（已在 PATH 时跳过 mason）
--   mason         : mason-registry 包名（缺失时 ensure_lsp 自动装）
--   external_owner: 可选。设了表示该 server 不由 vim.lsp.enable 启动，而是某
--                   外部插件接管启动逻辑（字符串 = 插件名/原因）。core/lsp.lua
--                   过滤这些条目，避免 mason 装好却仍被 vim 原生 enable 误启
--                   ——以及反过来"以为它没装"的两源真相风险。
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
		verify_cmd = { "rust-analyzer", "--version" },
	},
	-- tinymist：Typst LSP + 预览后端（typst-preview.nvim 复用同一份二进制）
	{ server = "tinymist", bin = "tinymist", mason = "tinymist" },
	{ server = "ty", bin = "ty", mason = "ty" },
	{ server = "tsp_server", bin = "tsp-server", mason = "tsp-server" },
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
}

-- Formatter 的**安装意图**（纯 install plane 事实）：打开某 ft 时 Mason 要兜底装上
-- 哪些 formatter 二进制。**不是** runtime formatter 映射——"这个 buffer 跑什么"由
-- plugins/format/conform.lua 自持（含 go/ts/markdown 的运行时 picker）。迁移前两个
-- 事实共一张表、六个 ft 被 conform 覆写导致表值说谎；拆分后本表只留 TOOL_MAP 可装
-- 的条目（d2/tofu/rustup/mise/scheme 系 formatter 不经 Mason，来路注释在 conform.lua）。
---@type table<string, string[]>
local FORMATTER_INSTALLS_BY_FT = {
	lua = { "stylua" },
	python = { "ruff_format" },
	-- goimports 是 conform 的 go picker 的 fallback 分支用的二进制；golangci-lint
	-- 已在 LINTERS_BY_FT 里登记，复用同一个二进制。
	go = { "goimports" },
	sh = { "shfmt" },
	bash = { "shfmt" },
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
	-- sh/bash: shellcheck 由 bashls 内置处理，不重复跑
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
}

local M = {}

-- 安装缺失的 LSP servers（VeryLazy 时调用）
function M.ensure_lsp()
	local map = {}
	for _, t in ipairs(LSP_TOOLS) do
		map[t.bin] = t
	end
	ensure_tools(vim.tbl_map(function(t) return t.bin end, LSP_TOOLS), map)
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

-- 打开某 filetype 时按需安装对应 formatter/linter（FileType autocmd 调用）
---@param ft string
function M.ensure_for_ft(ft)
	local seen = {}
	for _, name in ipairs(FORMATTER_INSTALLS_BY_FT[ft] or {}) do
		seen[name] = true
	end
	for _, name in ipairs(LINTERS_BY_FT[ft] or {}) do
		seen[name] = true
	end
	local list = vim.tbl_keys(seen)
	if #list > 0 then
		ensure_tools(list, TOOL_MAP)
	end
end

---@return table<string, string[]>
function M.get_linters_by_ft() return vim.deepcopy(LINTERS_BY_FT) end

-- 按工具名按需安装（供需要"路径触发"的工具使用，如 actionlint 仅在
-- .github/workflows/* 下才想装）
---@param name string TOOL_MAP key
function M.ensure_tool(name) ensure_tools({ name }, TOOL_MAP) end

return M
