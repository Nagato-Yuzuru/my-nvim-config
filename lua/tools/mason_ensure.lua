-- Mason 自动安装编排（LSP + formatter + linter 的 SSOT）；安装原语在 tools/mason_install.lua

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
-- 注意：三个 Scheme 系 LSP（racket / guile / steel）不在本表——它们走
-- scheme_toolchain.lua 的 presence-check + 手动安装提示。
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
	{ server = "terraformls", bin = "terraform-ls", mason = "terraform-ls" },
	{ server = "dockerls", bin = "docker-langserver", mason = "dockerfile-language-server" },
	{ server = "just_ls", bin = "just-lsp", mason = "just-lsp" },
	{ server = "denols", bin = "deno", mason = "deno" },
	{ server = "vtsls", bin = "vtsls", mason = "vtsls" },
	{ server = "eslint", bin = "vscode-eslint-language-server", mason = "eslint-lsp" },
	{ server = "helm_ls", bin = "helm_ls", mason = "helm-ls" },
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
	prettier = { bin = "prettier", mason = "prettier" },
	taplo = { bin = "taplo", mason = "taplo" },
	shellcheck = { bin = "shellcheck", mason = "shellcheck" },
	hadolint = { bin = "hadolint", mason = "hadolint" },
	golangcilint = { bin = "golangci-lint", mason = "golangci-lint" },
	yamllint = { bin = "yamllint", mason = "yamllint" },
	actionlint = { bin = "actionlint", mason = "actionlint" },
	typstyle = { bin = "typstyle", mason = "typstyle" },
}

---@type table<string, string[]>
local FORMATTERS_BY_FT = {
	lua = { "stylua" },
	python = { "ruff_format" },
	-- 实际 formatter 由 plugins/format/conform.lua 的 pick_go_formatter 运行时决定：
	-- 仓库有 .golangci.{yml,yaml,toml} → golangci-lint fmt（按仓库 formatters 块跑
	-- gofumpt / gci / golines / 自定义 import 分组），否则 fallback 到 goimports。
	-- 这里登记 goimports 只是为了让 Mason 把 fallback 的二进制装上；golangci-lint
	-- 已在 LINTERS_BY_FT 里登记，复用同一个二进制。
	go = { "goimports" },
	sh = { "shfmt" },
	bash = { "shfmt" },
	zsh = { "shfmt" },
	json = { "prettier" },
	jsonc = { "prettier" },
	yaml = { "prettier" },
	markdown = { "prettier" },
	-- ts/js: conform.lua 会按 buffer root 运行时切换 deno_fmt / prettier
	-- 这里列 prettier 是为了 Mason 自动安装；deno_fmt 随 deno 二进制而来
	typescript = { "prettier" },
	typescriptreact = { "prettier" },
	javascript = { "prettier" },
	javascriptreact = { "prettier" },
	toml = { "taplo" },
	-- d2 fmt 由 d2 CLI 自带（brew 装），不经 Mason 管理；conform 的 d2 formatter 从 PATH 找
	d2 = { "d2" },
	-- terraform_fmt 调用系统 terraform CLI，不经 Mason 管理
	terraform = { "terraform_fmt" },
	["terraform-vars"] = { "terraform_fmt" },
	-- rustfmt 跟着 rustup（rustup component add rustfmt），不走 Mason；conform
	-- 自带的 rustfmt formatter 会从 PATH 找
	rust = { "rustfmt" },
	typst = { "typstyle" },
	-- Scheme 系：raco_fmt / schemat 都不在 mason，TOOL_MAP 也没登记，
	-- 所以 ensure_tools 会跳过它们；formatter 命令本体在 plugins/format/conform.lua
	-- 里定义，缺失时由 plugins/lang/scheme.lua 触发的 scheme_toolchain 提示安装。
	racket = { "raco_fmt" },
	scheme = { "schemat" },
}

---@type table<string, string[]>
local LINTERS_BY_FT = {
	-- sh/bash: shellcheck 由 bashls 内置处理，不重复跑
	dockerfile = { "hadolint" },
	go = { "golangcilint" },
	-- yamllint 跑风格/缩进/重复 key 检查；schema 校验由 yamlls 负责。
	-- actionlint 只对 .github/workflows/* 有意义（懂 expr / needs / matrix），
	-- 不放在这里自动跑，由 plugins/lint/nvim-lint.lua 里按路径触发。
	yaml = { "yamllint" },
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
	for _, name in ipairs(FORMATTERS_BY_FT[ft] or {}) do
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

-- 返回类型用 union 兼容 conform 的 `formatters_by_ft`（允许 fun(bufnr):string[]
-- 取代静态 string[]）；存储侧只放 string[]，但 caller 拿到后会插入 picker 函数
-- （见 plugins/format/conform.lua 的 ts/js / markdown 分流），union 让那种赋值不报型。
---@return table<string, string[] | fun(bufnr: integer): string[]>
function M.get_formatters_by_ft() return vim.deepcopy(FORMATTERS_BY_FT) end
---@return table<string, string[]>
function M.get_linters_by_ft() return vim.deepcopy(LINTERS_BY_FT) end

-- 按工具名按需安装（供需要"路径触发"的工具使用，如 actionlint 仅在
-- .github/workflows/* 下才想装）
---@param name string TOOL_MAP key
function M.ensure_tool(name) ensure_tools({ name }, TOOL_MAP) end

return M
