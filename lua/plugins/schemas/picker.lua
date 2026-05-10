-- :SchemaSelect — 给 JSON / YAML / TOML buffer 注入一个 schema 引用。
--
-- 数据源：SchemaStore.nvim 提供的 JSON 大全 + 本仓维护的 cloud_native_schema 增补。
-- 输出形式按 ft 分流：
--   * yaml → buffer 顶端插一行 `# yaml-language-server: $schema=<url>`，yamlls 会读它
--   * toml → buffer 顶端插一行 `#:schema <url>`，taplo 会读它
--   * json/jsonc → 复制 url 到 + 寄存器 + notify 提示用户手动加 "$schema": ...
--                  （JSON 没有"行级 schema 注释"协议，只能写到文档里）
--
-- 这个模块独立于 mason 和 lspconfig：注册的是一个 user command + 一个 keymap，
-- 真正的 schema 加载（require schemastore）发生在用户调用 :SchemaSelect 时。
-- 装载也无需 lazy spec —— init.lua 直接 require 后调 setup() 即可。

local M = {}

local function apply_schema_url(url, name)
	name = name or url
	local ft = vim.bo.filetype
	if ft == "yaml" then
		vim.api.nvim_buf_set_lines(0, 0, 0, false, { "# yaml-language-server: $schema=" .. url })
		vim.notify("Schema applied: " .. name)
	elseif ft == "toml" then
		vim.api.nvim_buf_set_lines(0, 0, 0, false, { "#:schema " .. url })
		vim.notify("Schema applied: " .. name)
	elseif ft == "json" or ft == "jsonc" then
		vim.fn.setreg("+", url)
		vim.notify("Copied schema URL to clipboard: " .. url, vim.log.levels.INFO)
		vim.notify('Add manually: "$schema": "' .. url .. '"', vim.log.levels.INFO)
	end
end

local function select_schema_and_insert()
	local status, schemastore = pcall(require, "schemastore")
	local options = {}

	if status then
		options = vim.list_extend({}, schemastore.json.schemas() or {})
	end

	local schemas = require("plugins.schemas.cloud_native_schema")
	for i = #schemas, 1, -1 do
		table.insert(options, 1, schemas[i])
	end
	table.insert(options, 1, { name = "[ Enter custom URL... ]", url = "__custom__" })

	vim.ui.select(options, {
		prompt = "Select Schema to Apply",
		format_item = function(item)
			local desc = item.description and (" - " .. item.description) or ""
			if #desc > 50 then
				desc = string.sub(desc, 1, 47) .. "..."
			end
			return item.name .. desc
		end,
	}, function(choice)
		if not choice then
			return
		end
		if choice.url == "__custom__" then
			vim.ui.input({ prompt = "Schema URL: " }, function(input)
				if input and input ~= "" then
					apply_schema_url(input)
				end
			end)
			return
		end
		apply_schema_url(choice.url, choice.name)
	end)
end

function M.setup()
	vim.api.nvim_create_user_command("SchemaSelect", select_schema_and_insert, {})
	vim.keymap.set("n", "<leader>cs", select_schema_and_insert, { desc = "Select Schema" })
end

return M
