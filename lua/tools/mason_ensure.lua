local U = require("plugins.shared.ensure_utils")

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
	black         = { bin = "black",         mason = "black" },
	gofumpt       = { bin = "gofumpt",       mason = "gofumpt" },
	goimports     = { bin = "goimports",     mason = "goimports" },
	shfmt         = { bin = "shfmt",         mason = "shfmt" },
	prettier      = { bin = "prettier",      mason = "prettier" },
	taplo         = { bin = "taplo",         mason = "taplo" },
	terraform_fmt = { bin = "terraform-ls",  mason = "terraform-ls" },
	shellcheck    = { bin = "shellcheck",    mason = "shellcheck" },
	hadolint      = { bin = "hadolint",      mason = "hadolint" },
}

local FORMATTERS_BY_FT = {
	lua                = { "stylua" },
	python             = { "ruff_format", "black" },
	go                 = { "gofumpt", "goimports" },
	sh                 = { "shfmt" },
	bash               = { "shfmt" },
	zsh                = {},
	json               = { "prettier" },
	jsonc              = { "prettier" },
	yaml               = { "prettier" },
	markdown           = { "prettier" },
	toml               = { "taplo" },
	d2                 = { "d2" },
	terraform          = { "terraform_fmt" },
	["terraform-vars"] = { "terraform_fmt" },
}

local LINTERS_BY_FT = {
	sh         = { "shellcheck" },
	bash       = { "shellcheck" },
	dockerfile = { "hadolint" },
}

local M = {}

-- 安装缺失的 LSP servers（VeryLazy 时调用）
function M.ensure_lsp()
	local map = {}
	for _, t in ipairs(LSP_TOOLS) do map[t.bin] = t end
	U.ensure_tools(vim.tbl_map(function(t) return t.bin end, LSP_TOOLS), map)
end

-- 打开某 filetype 时按需安装对应 formatter/linter（FileType autocmd 调用）
function M.ensure_for_ft(ft)
	local seen = {}
	for _, name in ipairs(FORMATTERS_BY_FT[ft] or {}) do seen[name] = true end
	for _, name in ipairs(LINTERS_BY_FT[ft] or {}) do seen[name] = true end
	local list = vim.tbl_keys(seen)
	if #list > 0 then U.ensure_tools(list, TOOL_MAP) end
end

function M.get_formatters_by_ft() return vim.deepcopy(FORMATTERS_BY_FT) end
function M.get_linters_by_ft() return vim.deepcopy(LINTERS_BY_FT) end

return M
