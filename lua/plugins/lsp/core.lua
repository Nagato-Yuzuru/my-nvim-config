---
--- Created by yuzuru.
--- DateTime: 2025/11/4 00:46
---
-- lua/plugins/lsp/core.lua
return {
	-- 安装器（装 LSP/DAP/CLI 工具）
	{ "williamboman/mason.nvim", build = ":MasonUpdate", config = true },

	-- mason ↔ lspconfig 桥接
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			local servers = {
				lua_ls = "lua-language-server",
				pyright = "pyright",
				gopls = "gopls",
				jsonls = "vscode-json-language-server",
				yamlls = "yaml-language-server",
				bashls = "bash-language-server",
				taplo = "taplo",
				marksman = "marksman",
				clangd = "clangd",
			}
			local ensure_installed = {}
			for lsp_name, binary_name in pairs(servers) do
				if vim.fn.executable(binary_name) ~= 1 then
					table.insert(ensure_installed, lsp_name)
				end
			end

			require("mason").setup()
			require("mason-lspconfig").setup({
				ensure_installed = ensure_installed,
				automatic_installation = true,
			})
		end,
	},
	-- ★ 新 API 版 LSP 启动器
	{
		"neovim/nvim-lspconfig", -- 仅为了 util/根目录工具；不再调用 .setup()
		event = { "BufReadPre", "BufNewFile" },
		cmd = { "LspInfo", "LspLog" },
		dependencies = { "b0o/SchemaStore.nvim" },
		config = function()
			-- 禁用 nvim-lspconfig 内置自动启动（避免与 start_for_ft 重复）
			vim.lsp.config("gopls", { autostart = false })

			-- 绑定补全能力（blink.cmp 可选）
			local caps = vim.lsp.protocol.make_client_capabilities()
			pcall(function()
				caps = vim.tbl_deep_extend("force", caps, require("blink.cmp").get_lsp_capabilities() or {})
			end)
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspKeymaps", { clear = true }),
				callback = function(args)
					local bufnr = args.buf
					local map = function(mode, lhs, rhs, desc)
						vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, noremap = true, silent = true, desc = desc })
					end

					map("n", "<C-q>", vim.lsp.buf.hover, "LSP: Hover") -- 你的习惯
					map({ "n", "i", "s" }, "<A-P>", vim.lsp.buf.signature_help, "LSP: Signature Help")
					map("n", "gd", vim.lsp.buf.definition, "Goto Definition")
					map("n", "gD", vim.lsp.buf.declaration, "Goto Declaration")
					map("n", "gi", vim.lsp.buf.implementation, "Goto Implementation")
					map("n", "gr", vim.lsp.buf.references, "References")
					map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
					map("n", "<leader>ca", vim.lsp.buf.code_action, "Code Action")

					-- 可选：自动开启 inlay hints
					if vim.lsp.inlay_hint then
						pcall(vim.lsp.inlay_hint, bufnr, true)
					end
				end,
			})

			local on_attach = function(_, bufnr)
				if vim.lsp.inlay_hint then
					pcall(vim.lsp.inlay_hint, bufnr, true)
				end
			end

			local function start_for_ft(ft, cfg)
				vim.api.nvim_create_autocmd("FileType", {
					pattern = ft,
					callback = function(ev)
						local root = cfg.root_dir
							or vim.fs.root(ev.buf, cfg.root_patterns or { ".git" })
							or vim.fn.getcwd()
						local final = vim.tbl_deep_extend("force", {
							name = cfg.name,
							cmd = cfg.cmd, -- 依赖 mason，将二进制放进 PATH
							root_dir = root,
							capabilities = caps,
							on_attach = on_attach,
							settings = cfg.settings,
							single_file_support = (cfg.single_file_support ~= false),
						}, cfg.extra or {})
						vim.lsp.start(final)
					end,
				})
			end

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

			-- 注册命令
			vim.api.nvim_create_user_command("SchemaSelect", select_schema_and_insert, {})
			vim.keymap.set("n", "<leader>cs", select_schema_and_insert, { desc = "Select Schema" })

			-- Lua (lua_ls)
			start_for_ft({ "lua" }, {
				name = "lua_ls",
				cmd = { "lua-language-server" },
				root_patterns = { ".luarc.json", ".luacheckrc", ".git" },
				settings = {
					Lua = {
						diagnostics = { globals = { "vim" } },
						workspace = { checkThirdParty = false },
						hint = { enable = true },
					},
				},
			})

			-- Python (pyright) — 补全 + hover + go-to-definition
			start_for_ft({ "python" }, {
				name = "pyright",
				cmd = { "pyright-langserver", "--stdio" },
				root_patterns = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
				settings = {
					python = {
						analysis = {
							autoSearchPaths = true,
							useLibraryCodeForTypes = true,
							typeCheckingMode = "basic",
						},
					},
				},
			})

			-- Python (ruff) — lint + 快速修复
			start_for_ft({ "python" }, {
				name = "ruff",
				cmd = { "ruff", "server" },
				root_patterns = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
				settings = {
					organizeImports = true,
				},
			})

			-- Python (ty) — 类型检查
			start_for_ft({ "python" }, {
				name = "ty",
				cmd = { "ty", "server" },
				root_patterns = { "pyproject.toml", "ty.toml", ".git" },
			})

			-- Go (gopls)
			start_for_ft({ "go", "gomod", "gowork", "gotmpl" }, {
				name = "gopls",
				cmd = { "gopls" },
				root_patterns = { "go.work", "go.mod", ".git" },
				settings = {
					gopls = {
						usePlaceholders = true,
						completeUnimported = true,
						analyses = { unusedparams = true, unreachable = true },
						experimentalStandaloneFiles = true,
					},
				},
			})

			-- JSON (jsonls) + SchemaStore
			start_for_ft({ "json", "jsonc" }, {
				name = "jsonls",
				cmd = { "vscode-json-language-server", "--stdio" },
				settings = {
					json = {
						schemas = require("schemastore").json.schemas(),
						validate = { enable = true },
					},
				},
			})

			-- YAML (yamlls) + SchemaStore
			start_for_ft({ "yaml", "yml" }, {
				name = "yamlls",
				cmd = { "yaml-language-server", "--stdio" },
				settings = {
					yaml = {
						keyOrdering = false,
						schemaStore = { enable = false, url = "" },
						schemas = require("schemastore").yaml.schemas(),
						format = { enable = true },
						validate = true,
						completion = true,
						hover = true,
					},
				},
			})

			-- Bash / Zsh (bashls)
			start_for_ft({ "sh", "bash", "zsh" }, {
				name = "bashls",
				cmd = { "bash-language-server", "start" },
			})

			-- TOML (taplo)
			start_for_ft({ "toml" }, {
				name = "taplo",
				cmd = { "taplo", "lsp", "stdio" },
				settings = {
					taplo = {
						schema = {
							enable = true,
							respositoryEnable = true,
						},
					},
					formatting = {
						alignEntries = true,
						alignComments = true,
						arrayTrailingComma = true,
						arrayAutoExpand = true,
						compactArrays = true,
						compactInlineTables = true,
					},
				},
			})

			-- Markdown (marksman)
			start_for_ft({ "markdown", "markdown.mdx" }, {
				name = "marksman",
				cmd = { "marksman", "server" },
			})

			-- C / C++ (clangd)
			start_for_ft({ "c", "cpp", "objc", "objcpp" }, {
				name = "clangd",
				cmd = {
					"clangd",
					"--background-index",
					"--clang-tidy",
					"--header-insertion=never",
					"--offset-encoding=utf-16",
				},
				root_patterns = { "compile_commands.json", ".git" },
				extra = { init_options = { fallbackFlags = { "-std=c++20" } } },
			})
		end,
	},
}
