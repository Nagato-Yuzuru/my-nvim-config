-- ~/.config/nvim/lua/plugins/none-ls.lua

return function()
	local null_ls = require("null-ls")
	local builtins = null_ls.builtins

	-- 尝试加载 none-ls-extras，用于对 ruff 的支持
	-- local extras_ok, extras = pcall(require, "none-ls-extras")
	-- if extras_ok then
	--     extras.setup()
	-- else
	--     vim.notify("none-ls-extras 加载失败，请检查安装状态", vim.log.levels.WARN)
	-- end

	-- 定义 sources 列表，注意有可能 extras 的模块加载失败时返回 nil
	local sources = {
		-- Lua 格式化使用 stylua
		builtins.formatting.stylua,
		builtins.formatting.shfmt.with({
			filetypes = { "sh", "zsh" },
			extra_args = { "-i", "4" },
		}),
		builtins.formatting.gofmt,
		-- YAML / JSON 格式化使用 prettier
		builtins.formatting.prettier,
		builtins.formatting.clang_format,

		-- builtins.diagnostics.ruff,
		-- builtins.formatting.ruff,
		-- builtins.code_actions.ruff,

		-- null_ls.diagnostics.cpplint,
		-- null_ls.formatting.jq,
		-- null_ls.code_actions.eslint,
		-- Python
		-- extras_ok and extras.code_actions and extras.code_actions.ruff or nil,
		-- extras_ok and extras.diagnostics and extras.diagnostics.ruff or nil,
		builtins.diagnostics.mypy.with({
			to_temp_file = true,
			extra_args = function(params)
				return {
					"--shadow-file",
					params.bufname,
					params.temp_path,
				}
			end,
		}),
		builtins.diagnostics.pydoclint,
		builtins.diagnostics.zsh,
	}
	-- 过滤掉可能为 nil 的项
	local filtered_sources = {}
	for _, src in ipairs(sources) do
		if src then
			table.insert(filtered_sources, src)
		end
	end

	null_ls.setup({
		debug = true,
		sources = filtered_sources,
		temp_dir = "/tmp",
	})

	local custom_format = function()
		local clients = vim.lsp.get_active_clients()
		local bufnr = vim.api.nvim_get_current_buf()

		for _, client in ipairs(clients) do
			if client.name == "null-ls" then
				vim.lsp.buf.format({
					filter = function(c)
						return c.name == "null-ls"
					end,
					bufnr = bufnr,
				})
				return
			end
		end

		vim.lsp.buf.format({
			filter = function(c)
				return c.supports_method("textDocument/formatting")
			end,
			async = true,
		})
	end

	vim.api.nvim_create_autocmd("BufWritePre", {
		pattern = "*",
		callback = custom_format,
	})

	-- 与 Mason 集成，自动安装列出的工具
	require("mason-null-ls").setup({
		ensure_installed = {
			"stylua", -- Lua 格式化工具
			"ruff", -- Python 代码检查（由 none-ls-extras 支持）
			"shfmt", -- Shell 格式化
			-- "shellcheck", -- Shell 诊断
			"prettier", -- YAML/JSON 格式化
		},
		automatic_installation = true,
	})
end
