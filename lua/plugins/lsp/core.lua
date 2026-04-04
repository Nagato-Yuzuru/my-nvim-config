---
--- Created by yuzuru.
--- DateTime: 2025/11/4 00:46
---
-- lua/plugins/lsp/core.lua
return {
	-- 安装器（装 LSP/DAP/CLI 工具）
	{ "williamboman/mason.nvim", build = ":MasonUpdate", config = true },

	-- mason ↔ lspconfig 桥接（仅负责自动安装缺失的 server）
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			local servers = {
				lua_ls       = "lua-language-server",
				pyright      = "pyright",
				gopls        = "gopls",
				jsonls       = "vscode-json-language-server",
				yamlls       = "yaml-language-server",
				bashls       = "bash-language-server",
				taplo        = "taplo",
				marksman     = "marksman",
				clangd       = "clangd",
				terraformls  = "terraform-ls",
				dockerls     = "docker-langserver",
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

	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		cmd = { "LspLog" },
		dependencies = { "b0o/SchemaStore.nvim" },
		config = function()
			-- 绑定补全能力（blink.cmp 可选）
			local caps = vim.lsp.protocol.make_client_capabilities()
			pcall(function()
				caps = vim.tbl_deep_extend("force", caps, require("blink.cmp").get_lsp_capabilities() or {})
			end)

			-- 全局默认：capabilities + inlay hints
			vim.lsp.config("*", {
				capabilities = caps,
				on_attach = function(_, bufnr)
					if vim.lsp.inlay_hint then
						pcall(vim.lsp.inlay_hint, bufnr, true)
					end
				end,
			})

			-- LspAttach 快捷键
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspKeymaps", { clear = true }),
				callback = function(args)
					local bufnr = args.buf
					local map = function(mode, lhs, rhs, desc)
						vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, noremap = true, silent = true, desc = desc })
					end

					map("n", "<C-q>", vim.lsp.buf.hover, "LSP: Hover")
					map({ "n", "i", "s" }, "<A-P>", vim.lsp.buf.signature_help, "LSP: Signature Help")
					map("n", "gd", vim.lsp.buf.definition, "Goto Definition")
					map("n", "gD", vim.lsp.buf.declaration, "Goto Declaration")
					map("n", "gi", vim.lsp.buf.implementation, "Goto Implementation")
					map("n", "gr", vim.lsp.buf.references, "References")
					map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
					map("n", "<leader>ca", vim.lsp.buf.code_action, "Code Action")
					-- <leader>n* 对齐 IdeaVim
					map("n", "<leader>nd", vim.lsp.buf.definition, "Goto Definition")
					map("n", "<leader>nD", vim.lsp.buf.type_definition, "Goto Type Definition")
					map("n", "<leader>ni", vim.lsp.buf.implementation, "Goto Implementation")
					map("n", "<leader>nu", vim.lsp.buf.references, "Find Usages")
				end,
			})

			-- ── Server configs ────────────────────────────────────────────

			-- Lua (lua_ls)
			vim.lsp.config("lua_ls", {
				cmd = { "lua-language-server" },
				filetypes = { "lua" },
				root_dir = function(fname)
					return vim.fs.root(fname, { ".luarc.json", ".luacheckrc", ".git" }) or vim.fn.getcwd()
				end,
				settings = {
					Lua = {
						diagnostics = { globals = { "vim" } },
						workspace = { checkThirdParty = false },
						hint = { enable = true },
					},
				},
			})
			vim.lsp.enable("lua_ls")

			-- Python (pyright) — 补全 + hover + go-to-definition
			vim.lsp.config("pyright", {
				cmd = { "pyright-langserver", "--stdio" },
				filetypes = { "python" },
				root_dir = function(fname)
					return vim.fs.root(fname, { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" })
						or vim.fn.getcwd()
				end,
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
			vim.lsp.enable("pyright")

			-- Python (ruff) — lint + 快速修复
			vim.lsp.config("ruff", {
				cmd = { "ruff", "server" },
				filetypes = { "python" },
				root_dir = function(fname)
					return vim.fs.root(fname, { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" })
						or vim.fn.getcwd()
				end,
				settings = { organizeImports = true },
			})
			vim.lsp.enable("ruff")

			-- Python (ty) — 类型检查
			vim.lsp.config("ty", {
				cmd = { "ty", "server" },
				filetypes = { "python" },
				root_dir = function(fname)
					return vim.fs.root(fname, { "pyproject.toml", "ty.toml", ".git" }) or vim.fn.getcwd()
				end,
			})
			vim.lsp.enable("ty")

			-- Go (gopls)
			vim.lsp.config("gopls", {
				cmd = { "gopls" },
				filetypes = { "go", "gomod", "gowork", "gotmpl" },
				root_dir = function(fname)
					return vim.fs.root(fname, { "go.work", "go.mod", ".git" }) or vim.fn.getcwd()
				end,
				settings = {
					gopls = {
						usePlaceholders = true,
						completeUnimported = true,
						analyses = { unusedparams = true, unreachable = true },
						experimentalStandaloneFiles = true,
					},
				},
			})
			vim.lsp.enable("gopls")

			-- JSON (jsonls) + SchemaStore
			vim.lsp.config("jsonls", {
				cmd = { "vscode-json-language-server", "--stdio" },
				filetypes = { "json", "jsonc" },
				settings = {
					json = {
						schemas = require("schemastore").json.schemas(),
						validate = { enable = true },
					},
				},
			})
			vim.lsp.enable("jsonls")

			-- YAML (yamlls) + SchemaStore
			vim.lsp.config("yamlls", {
				cmd = { "yaml-language-server", "--stdio" },
				filetypes = { "yaml", "yml" },
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
			vim.lsp.enable("yamlls")

			-- Bash / Zsh (bashls)
			vim.lsp.config("bashls", {
				cmd = { "bash-language-server", "start" },
				filetypes = { "sh", "bash", "zsh" },
				settings = {
					bashIde = { shellcheckPath = "shellcheck" },
				},
			})
			vim.lsp.enable("bashls")

			-- TOML (taplo)
			vim.lsp.config("taplo", {
				cmd = { "taplo", "lsp", "stdio" },
				filetypes = { "toml" },
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
			vim.lsp.enable("taplo")

			-- Markdown (marksman)
			vim.lsp.config("marksman", {
				cmd = { "marksman", "server" },
				filetypes = { "markdown", "markdown.mdx" },
			})
			vim.lsp.enable("marksman")

			-- Terraform / OpenTofu (terraform-ls)
			vim.lsp.config("terraformls", {
				cmd = { "terraform-ls", "serve" },
				filetypes = { "terraform", "terraform-vars" },
				root_dir = function(fname)
					return vim.fs.root(fname, { ".terraform", ".terraform.lock.hcl", ".git" }) or vim.fn.getcwd()
				end,
				settings = {
					terraform = {
						path = vim.fn.executable("tofu") == 1 and "tofu" or "terraform",
						experimentalFeatures = {
							validateOnSave = true,
							prefillRequiredFields = true,
						},
					},
				},
			})
			vim.lsp.enable("terraformls")

			-- Dockerfile (dockerls)
			vim.lsp.config("dockerls", {
				cmd = { "docker-langserver", "--stdio" },
				filetypes = { "dockerfile" },
				root_dir = function(fname)
					return vim.fs.root(fname, { "Dockerfile", ".git" }) or vim.fn.getcwd()
				end,
			})
			vim.lsp.enable("dockerls")

			-- C / C++ (clangd)
			vim.lsp.config("clangd", {
				cmd = {
					"clangd",
					"--background-index",
					"--clang-tidy",
					"--header-insertion=never",
					"--offset-encoding=utf-16",
				},
				filetypes = { "c", "cpp", "objc", "objcpp" },
				root_dir = function(fname)
					return vim.fs.root(fname, { "compile_commands.json", ".git" }) or vim.fn.getcwd()
				end,
				init_options = { fallbackFlags = { "-std=c++20" } },
			})
			vim.lsp.enable("clangd")

			-- ── Schema 工具 ───────────────────────────────────────────────

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
}
