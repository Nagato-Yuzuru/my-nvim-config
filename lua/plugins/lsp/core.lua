return {
	-- Mason: 工具安装器
	{
		"williamboman/mason.nvim",
		build = ":MasonUpdate",
		config = function()
			require("mason").setup()

			local mason_ensure = require("tools.mason_ensure")

			-- VeryLazy 时自动安装缺失的 LSP server（不阻塞启动）
			vim.api.nvim_create_autocmd("User", {
				pattern = "VeryLazy",
				once = true,
				callback = mason_ensure.ensure_lsp,
			})

			-- 打开对应文件类型时按需安装 formatter/linter（注册必须在启动时完成）
			vim.api.nvim_create_autocmd("FileType", {
				callback = function(ev)
					mason_ensure.ensure_for_ft(vim.bo[ev.buf].filetype)
				end,
			})

			-- Schema 选择工具（JSON/YAML/TOML 用）
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
						if #desc > 50 then desc = string.sub(desc, 1, 47) .. "..." end
						return item.name .. desc
					end,
				}, function(choice)
					if not choice then return end
					if choice.url == "__custom__" then
						vim.ui.input({ prompt = "Schema URL: " }, function(input)
							if input and input ~= "" then apply_schema_url(input) end
						end)
						return
					end
					apply_schema_url(choice.url, choice.name)
				end)
			end

			vim.api.nvim_create_user_command("SchemaSelect", select_schema_and_insert, {})
			vim.keymap.set("n", "<leader>cs", select_schema_and_insert, { desc = "Select Schema" })
		end,
	},

	-- SchemaStore（jsonls / yamlls 的 lsp/*.lua 中 require）
	{ "b0o/SchemaStore.nvim", lazy = true },
}
