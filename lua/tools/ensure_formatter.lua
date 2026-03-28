---
--- Created by colas.
--- DateTime: 2025/11/4 13:42
---
-- lua/plugins/format/ensure.lua
local U = require("plugins.shared.ensure_utils")

local TOOL_MAP = {
	stylua = { bin = "stylua", mason = "stylua" },
	ruff_format = { bin = "ruff", mason = "ruff" },
	black = { bin = "black", mason = "black" },
	gofumpt = { bin = "gofumpt", mason = "gofumpt" },
	goimports = { bin = "goimports", mason = "goimports" },
	shfmt = { bin = "shfmt", mason = "shfmt" },
	prettier = { bin = "prettier", mason = "prettier" },
	taplo = { bin = "taplo", mason = "taplo" },
	terraform_fmt = { bin = "terraform-ls", mason = "terraform-ls" },
	-- sqlfluff = { bin = "sqlfluff",   mason = "sqlfluff" },
}

local FORMATTERS_BY_FT = {
	lua = { "stylua" },
	python = { "ruff_format", "black" },
	go = { "gofumpt", "goimports" },
	sh = { "shfmt" },
	bash = { "shfmt" },
	zsh = {}, -- 不自动格式化 zsh
	json = { "prettier" },
	jsonc = { "prettier" },
	yaml = { "prettier" },
	markdown = { "prettier" },
	toml = { "taplo" },
	d2 = { "d2" },
	terraform = { "terraform_fmt" },
	["terraform-vars"] = { "terraform_fmt" },
}

local M = {}

-- 在 VeryLazy 或首次命中文件类型时调用
function M.ensure_all()
	local uniq = {}
	for _, fs in pairs(FORMATTERS_BY_FT) do
		for _, name in ipairs(fs) do
			uniq[name] = true
		end
	end
	local list = {}
	for name in pairs(uniq) do
		table.insert(list, name)
	end
	U.ensure_tools(list, TOOL_MAP)
end

function M.get_formatters_by_ft()
	return vim.deepcopy(FORMATTERS_BY_FT)
end

return M
