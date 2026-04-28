-- Mason 安装原语 -----------------------------------------------------------

local function has_exec(bin)
	return vim.fn.executable(bin) == 1
end

local function ensure_mason_pkg(pkg_name)
	local ok, mr = pcall(require, "mason-registry")
	if not ok then
		return
	end
	local okp, pkg = pcall(mr.get_package, pkg_name)
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
	vim.notify(("Installing %s via Mason…"):format(pkg_name), vim.log.levels.INFO)
	pkg:install()
end

-- 根据 "name → {bin, mason}" 映射，缺失时自动安装
local function ensure_tools(list, tool_map)
	if vim.env.CI == "true" or vim.env.NO_AUTO_INSTALL == "1" then
		return
	end
	for _, name in ipairs(list) do
		local t = tool_map[name]
		if t and not has_exec(t.bin) then
			ensure_mason_pkg(t.mason)
		end
	end
end

-- 工具清单 -------------------------------------------------------------------

-- LSP servers（由 mason.nvim 触发安装）
local LSP_TOOLS = {
	{ bin = "lua-language-server", mason = "lua-language-server" },
	{ bin = "pyright-langserver", mason = "pyright" },
	{ bin = "ruff", mason = "ruff" },
	{ bin = "gopls", mason = "gopls" },
	{ bin = "vscode-json-language-server", mason = "json-lsp" },
	{ bin = "yaml-language-server", mason = "yaml-language-server" },
	{ bin = "bash-language-server", mason = "bash-language-server" },
	{ bin = "taplo", mason = "taplo" },
	{ bin = "marksman", mason = "marksman" },
	{ bin = "clangd", mason = "clangd" },
	{ bin = "terraform-ls", mason = "terraform-ls" },
	{ bin = "docker-langserver", mason = "dockerfile-language-server" },
	{ bin = "just-lsp", mason = "just-lsp" },
	{ bin = "deno", mason = "deno" },
	{ bin = "vtsls", mason = "vtsls" },
	{ bin = "vscode-eslint-language-server", mason = "eslint-lsp" },
	{ bin = "helm_ls", mason = "helm-ls" },
	-- rust-analyzer 优先用 rustup component（跟激活 toolchain 同步），mason 是兜底
	{ bin = "rust-analyzer", mason = "rust-analyzer" },
	-- tinymist：Typst LSP + 预览后端（typst-preview.nvim 复用同一份二进制）
	{ bin = "tinymist", mason = "tinymist" },
}

-- Formatter / Linter binary → Mason 包映射
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

local FORMATTERS_BY_FT = {
	lua = { "stylua" },
	python = { "ruff_format" },
	-- gofumpt 由 golangci-lint formatter 处理，goimports 负责 import 管理
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
	d2 = { "d2" },
	-- terraform_fmt 调用系统 terraform CLI，不经 Mason 管理
	terraform = { "terraform_fmt" },
	["terraform-vars"] = { "terraform_fmt" },
	-- rustfmt 跟着 rustup（rustup component add rustfmt），不走 Mason；conform
	-- 自带的 rustfmt formatter 会从 PATH 找
	rust = { "rustfmt" },
	typst = { "typstyle" },
}

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
	ensure_tools(
		vim.tbl_map(function(t)
			return t.bin
		end, LSP_TOOLS),
		map
	)
end

-- 打开某 filetype 时按需安装对应 formatter/linter（FileType autocmd 调用）
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

function M.get_formatters_by_ft()
	return vim.deepcopy(FORMATTERS_BY_FT)
end
function M.get_linters_by_ft()
	return vim.deepcopy(LINTERS_BY_FT)
end

-- 按工具名按需安装（供需要"路径触发"的工具使用，如 actionlint 仅在
-- .github/workflows/* 下才想装）
function M.ensure_tool(name)
	ensure_tools({ name }, TOOL_MAP)
end

return M
