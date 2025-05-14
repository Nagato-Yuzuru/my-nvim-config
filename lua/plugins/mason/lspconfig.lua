require("mason-lspconfig").setup({
	automatic_installation = true,
	handlers = {
		-- 可以在这里为特定 LSP 设置自定义处理程序
		function(server_name)
			local opts = {
				on_attach = on_attach,
				capabilities = capabilities,
			}

			-- == 特定服务器的配置 ==

			if server_name == "lua_ls" then
				opts.settings = {
					Lua = {
						runtime = { version = "LuaJIT" },
						diagnostics = { globals = { "vim" } },
						workspace = {
							library = vim.api.nvim_get_runtime_file("", true),
							checkThirdParty = false, -- 避免检查 ~/.local/share/nvim/lazy/*
						},
						telemetry = { enable = false },
					},
				}
			elseif server_name == "pyright" then
				opts.settings = {
					python = {
						analysis = {
							autoSearchPaths = true,
							useLibraryCodeForTypes = true,
							diagnosticMode = "workspace", -- 分析整个工作区
							-- typeCheckingMode = "basic" -- 或 "strict"
						},
					},
					pyright = {
						disableOrganizeImports = true,
					},
				}
			elseif server_name == "gopls" then
				opts.settings = {
					gopls = {
						analyses = {
							unusedparams = true,
						},
						staticcheck = true,
						-- usePlaceholders = true, -- 自动填充结构体字段
						-- completeUnimported = true, -- 补全未导入的包
					},
				}
			elseif server_name == "bashls" then
				-- bashls 通常不需要特殊配置，但 mason-lspconfig 会自动关联
				-- lspconfig 默认会将 bashls 关联到 bash, sh。我们需要确保 zsh 也被包含。
				-- mason-lspconfig 通常会处理好这个，但如果不行，可以在这里强制指定:
				-- opts.filetypes = { "sh", "bash", "zsh" }
				-- 注意：Zsh 支持可能不完美
				-- 检查 shellcheck 是否已安装
				opts.filetypes = { "sh", "bash", "zsh" }
				opts.settings = {
					bashIde = {
						shellcheckPath = vim.fn.exepath("shellcheck") or "", -- 显式告知 shellcheck 路径
					},
				}
			elseif server_name == "yamlls" then
				opts.settings = {
					yaml = {
						-- schemas = require('schemastore').yaml.schemas(), -- 如果安装了 schemastore
						validate = true,
						format = { enable = false }, -- 让 none-ls (prettier) 处理格式化
					},
				}
			elseif server_name == "jsonls" then
				opts.settings = {
					json = {
						-- schemas = require('schemastore').json.schemas(), -- 如果安装了 schemastore
						validate = { enable = true },
						format = { enable = false }, -- 让 none-ls (prettier) 处理格式化
					},
				}
				-- elseif server_name == "marksman" then -- Markdown LSP 示例
				--   -- marksman 配置
			end

			-- 使用 lspconfig 启动服务器
			lspconfig[server_name].setup(opts)
		end,
	},
})
