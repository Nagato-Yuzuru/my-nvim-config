-- Mason 安装原语 -----------------------------------------------------------

local function has_exec(bin) return vim.fn.executable(bin) == 1 end

local function ensure_mason_pkg(pkg_name)
	local ok, mr = pcall(require, "mason-registry"); if not ok then return end
	local okp, pkg = pcall(mr.get_package, pkg_name); if not okp then return end
	if not pkg:is_installed() then
		vim.notify(("Installing %s via Mason…"):format(pkg_name), vim.log.levels.INFO)
		pkg:install()
	end
end

-- 根据 "name → {bin, mason}" 映射，缺失时自动安装
local function ensure_tools(list, tool_map)
	if vim.env.CI == "true" or vim.env.NO_AUTO_INSTALL == "1" then return end
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
	{ bin = "lua-language-server",        mason = "lua-language-server" },
	{ bin = "pyright-langserver",          mason = "pyright" },
	{ bin = "ruff",                        mason = "ruff" },
	{ bin = "gopls",                       mason = "gopls" },
	{ bin = "vscode-json-language-server", mason = "json-lsp" },
	{ bin = "yaml-language-server",        mason = "yaml-language-server" },
	{ bin = "bash-language-server",        mason = "bash-language-server" },
	{ bin = "taplo",                       mason = "taplo" },
	{ bin = "marksman",                    mason = "marksman" },
	{ bin = "clangd",                      mason = "clangd" },
	{ bin = "terraform-ls",               mason = "terraform-ls" },
	{ bin = "docker-langserver",           mason = "dockerfile-language-server" },
}

-- Formatter / Linter binary → Mason 包映射
local TOOL_MAP = {
	stylua        = { bin = "stylua",        mason = "stylua" },
	ruff_format   = { bin = "ruff",          mason = "ruff" },
	goimports     = { bin = "goimports",     mason = "goimports" },
	shfmt         = { bin = "shfmt",         mason = "shfmt" },
	prettier      = { bin = "prettier",      mason = "prettier" },
	taplo         = { bin = "taplo",         mason = "taplo" },
	shellcheck      = { bin = "shellcheck",      mason = "shellcheck" },
	hadolint        = { bin = "hadolint",        mason = "hadolint" },
	golangcilint    = { bin = "golangci-lint",   mason = "golangci-lint" },
}

local FORMATTERS_BY_FT = {
	lua                = { "stylua" },
	python             = { "ruff_format" },
	-- gofumpt 由 golangci-lint formatter 处理，goimports 负责 import 管理
	go                 = { "goimports" },
	sh                 = { "shfmt" },
	bash               = { "shfmt" },
	zsh                = { "shfmt" },
	json               = { "prettier" },
	jsonc              = { "prettier" },
	yaml               = { "prettier" },
	markdown           = { "prettier" },
	toml               = { "taplo" },
	d2                 = { "d2" },
	-- terraform_fmt 调用系统 terraform CLI，不经 Mason 管理
	terraform          = { "terraform_fmt" },
	["terraform-vars"] = { "terraform_fmt" },
}

local LINTERS_BY_FT = {
	-- sh/bash: shellcheck 由 bashls 内置处理，不重复跑
	dockerfile = { "hadolint" },
	go         = { "golangcilint" },
}

local M = {}

-- 安装缺失的 LSP servers（VeryLazy 时调用）
function M.ensure_lsp()
	local map = {}
	for _, t in ipairs(LSP_TOOLS) do map[t.bin] = t end
	ensure_tools(vim.tbl_map(function(t) return t.bin end, LSP_TOOLS), map)
end

-- 打开某 filetype 时按需安装对应 formatter/linter（FileType autocmd 调用）
function M.ensure_for_ft(ft)
	local seen = {}
	for _, name in ipairs(FORMATTERS_BY_FT[ft] or {}) do seen[name] = true end
	for _, name in ipairs(LINTERS_BY_FT[ft] or {}) do seen[name] = true end
	local list = vim.tbl_keys(seen)
	if #list > 0 then ensure_tools(list, TOOL_MAP) end
end

function M.get_formatters_by_ft() return vim.deepcopy(FORMATTERS_BY_FT) end
function M.get_linters_by_ft() return vim.deepcopy(LINTERS_BY_FT) end

return M
