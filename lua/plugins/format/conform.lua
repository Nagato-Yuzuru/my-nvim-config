return {
	{
		"stevearc/conform.nvim",
		event = "BufWritePre",
		keys = {
			{
				"<leader>ff",
				function()
					if vim.bo.filetype == "python" then
						vim.lsp.buf.code_action({
							context = { only = { "source.fixAll.ruff" }, diagnostics = {} },
							apply = true,
						})
						vim.lsp.buf.code_action({
							context = { only = { "source.organizeImports.ruff" }, diagnostics = {} },
							apply = true,
						})
					end
					require("conform").format({ async = true, lsp_fallback = true })
				end,
				desc = "Format file",
			},
		},
		config = function()
			local conform = require("conform")
			local formatters_by_ft = require("tools.mason_ensure").get_formatters_by_ft()

			-- ts/js: Deno 项目用 deno fmt，其余用 prettier
			local function pick_js_formatter(bufnr)
				local deno_root = vim.fs.root(bufnr, { "deno.json", "deno.jsonc", "deno.lock" })
				if deno_root then
					return { "deno_fmt" }
				end
				return { "prettier" }
			end
			for _, ft in ipairs({ "typescript", "typescriptreact", "javascript", "javascriptreact" }) do
				formatters_by_ft[ft] = pick_js_formatter
			end

			-- markdown: 项目显式声明 .mdformat.toml 时走 mdformat（opt-in，由项目自行决定
			-- 是否需要 pymdown / MDX / admonition 等扩展的安全格式化），否则默认 prettier。
			-- 作用域随 .mdformat.toml 位置下沉：放 docs/ 下只影响 docs/；放项目根则全仓库。
			-- 安装：uv tool install mdformat --with mdformat-mkdocs --with mdformat-gfm --with mdformat-frontmatter
			-- mdformat 缺失时跳过 fmt（不降级到 prettier），以免破坏项目已声明要保留的语法。
			local function pick_md_formatter(bufnr)
				if vim.fs.root(bufnr, { ".mdformat.toml" }) then
					if vim.fn.executable("mdformat") == 1 then
						return { "mdformat" }
					end
					return {}
				end
				return { "prettier" }
			end
			formatters_by_ft.markdown = pick_md_formatter

			conform.setup({
				formatters_by_ft = formatters_by_ft,
				formatters = {
					-- mdformat 默认校验 "格式化前后 HTML 渲染一致"，但歧义字符（列表中的裸 `*` 等）
					-- 会被合法地转义触发误报。--no-validate 跳过该检查；MkDocs / MDX 扩展语法
					-- 仍由对应插件正确保留。
					mdformat = { prepend_args = { "--no-validate" } },
					-- Scheme / Racket：两者都不在 conform 内置 formatter 列表里，手动声明。
					-- 安装路径：raco fmt 由 sorawee/fmt 提供（raco pkg install fmt），
					--          schemat 由 raymond-w-ko/schemat 提供（cargo install schemat）。
					-- 缺失时静默跳过（has_exec 在 lua/tools/scheme_ensure.lua 会提示）。
					raco_fmt = {
						command = "raco",
						args = { "fmt", "-" },
						stdin = true,
					},
					schemat = {
						command = "schemat",
						stdin = true,
					},
				},
				-- Autoformat kill-switch：
				--   :FormatDisable   → 全局关（vim.g.disable_autoformat）
				--   :FormatDisable!  → 仅当前 buffer 关（vim.b.disable_autoformat）
				--   :FormatEnable    → 重新打开（同时清掉当前 buffer 的局部开关）
				-- 场景：mkdocs / 特殊 MDX / 带 frontmatter 的 YAML 等，fmt 会改坏语法时。
				format_on_save = function(bufnr)
					if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
						return nil
					end
					local ft = vim.bo[bufnr].filetype
					if ft == "zsh" then
						return { lsp_fallback = false }
					end
					return { timeout_ms = 1000, lsp_fallback = true }
				end,
			})
			vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

			vim.api.nvim_create_user_command("FormatDisable", function(args)
				if args.bang then
					vim.b.disable_autoformat = true
				else
					vim.g.disable_autoformat = true
				end
			end, {
				desc = "Disable autoformat-on-save (use ! for buffer-local)",
				bang = true,
			})
			vim.api.nvim_create_user_command("FormatEnable", function()
				vim.b.disable_autoformat = false
				vim.g.disable_autoformat = false
			end, { desc = "Re-enable autoformat-on-save" })
		end,
	},
}
