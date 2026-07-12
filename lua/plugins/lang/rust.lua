-- Rust 专属 nvim 集成
--
-- crates.nvim：Cargo.toml 里 hover 看 crate 信息、显示最新版本、一键升级、补全。
-- 编辑 Cargo.toml 必备（rust-analyzer 不管 Cargo.toml 本身的 UX）。
--
-- rustaceanvim：rust-analyzer LSP + neotest adapter + DAP 集成的统一前端。
-- test 发现走 rust-analyzer 的 runnables 请求，编得过 `cargo test` 的就找得到。
--   * 没有 setup() —— 配置走 `vim.g.rustaceanvim`，必须在 init 阶段设
--   * 接管 rust-analyzer：`core/lsp.lua` 已从 vim.lsp.enable 列表移除
--     "rust_analyzer"，顶层 `lsp/rust_analyzer.lua` 已删
--   * Test  → require("rustaceanvim.neotest") 在 plugins/runtime/neotest.lua 注册
--   * DAP   → 我们的 `dap/codelldb.lua` 仍是 codelldb adapter 的唯一真相源；
--             给 rustaceanvim 设 `dap.adapter = false` 让它别覆写

return {
	{
		"saecki/crates.nvim",
		-- BufNewFile 也要带上：`cargo init` 出新项目第一次开 Cargo.toml 时
		-- 没有 BufRead 事件，只有 BufNewFile —— 不加这条 crates.nvim 不会激活。
		event = { "BufRead Cargo.toml", "BufNewFile Cargo.toml" },
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			-- 补全走 lsp.enabled = true（in-process LSP）→ blink.cmp 经 LSP 渠道吃。
			-- 不设 completion.cmp / completion.coq —— 它们已被 crates.nvim 标记为
			-- deprecated，touch 一下就 warn，留空即可（默认就是 false）。
			completion = {
				crates = { enabled = true }, -- crate 名补全（in-buffer 触发逻辑）
			},
			lsp = {
				enabled = true,
				actions = true, -- code actions: upgrade / open docs.rs
				completion = true, -- blink.cmp 走 LSP 渠道吃 crates 的补全
				hover = true, -- K 显示 crate 信息
			},
			-- 行尾显示当前/最新版本
			text = {
				loading = "  Loading…",
				version = "  %s",
				prerelease = "  %s",
				yanked = "  %s yanked",
				nomatch = "  No match",
				upgrade = "  %s",
				error = "  Error",
			},
		},
		config = function(_, opts)
			require("crates").setup(opts)

			-- Cargo.toml buffer 内的局部键位（不挂到 leader 全局，免污染）
			vim.api.nvim_create_autocmd("BufRead", {
				pattern = "Cargo.toml",
				callback = function(ev)
					local map = function(lhs, rhs, desc)
						vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, silent = true, desc = desc })
					end
					local crates = require("crates")
					-- 用 <localleader>c* (",c*") 走"工具级"约定，跟 git/markdown/obsidian
					-- 一致，且避免跟全局 <leader>ca (code action) / <leader>cs (SchemaSelect) 冲突。
					map("<localleader>cu", crates.update_crate, "Crates: update crate under cursor")
					map("<localleader>cU", crates.upgrade_crate, "Crates: upgrade crate under cursor")
					map("<localleader>ca", crates.update_all_crates, "Crates: update all")
					map("<localleader>cA", crates.upgrade_all_crates, "Crates: upgrade all")
					map("<localleader>co", crates.show_popup, "Crates: open popup")
					map("<localleader>cv", crates.show_versions_popup, "Crates: show versions")
					map("<localleader>cf", crates.show_features_popup, "Crates: show features")
					map("<localleader>cd", crates.open_documentation, "Crates: open docs.rs")
					map("<localleader>cR", crates.open_repository, "Crates: open repository")
				end,
			})
		end,
	},
	{
		"mrcjkb/rustaceanvim",
		version = "^6",
		ft = { "rust" },
		-- 也被 plugins/runtime/neotest.lua 列为 dependency，确保 neotest 触发
		-- 加载时 `require("rustaceanvim.neotest")` 找得到（lazy 插件未加载前
		-- 不在 rtp 上）。lazy.nvim 会按 plugin name 合并两处 spec。
		init = function()
			-- vim.g.rustaceanvim 必须在 plugin 加载前设好 —— rustaceanvim 没有
			-- setup()，FileType rust 时直接读这张表。
			vim.g.rustaceanvim = {
				tools = {
					-- Test 走 neotest（plugins/runtime/neotest.lua 注册了 adapter）
					test_executor = "neotest",
				},
				server = {
					-- rustaceanvim 用 vim.lsp.start() 自启 rust-analyzer，**不**
					-- 走 vim.lsp.config("*")，所以 capabilities 必须显式塞进来。
					--
					-- ⚠️ 必须是 table（不是 function）—— rustaceanvim 的 type
					-- spec 写明 `@field capabilities table`，且 lsp/init.lua 的
					-- configure_file_watcher 直接 `vim.tbl_get(server_cfg.capabilities,
					-- 'workspace', 'didChangeWatchedFiles', 'dynamicRegistration')`
					-- 撞到 function 会报 "attempt to index a function value"。
					-- (`settings` 字段反而支持函数形式，是上游的不对称——别照搬。)
					--
					-- 副作用：在 init 阶段 require core.lsp（连带 require blink.cmp），
					-- 把 blink 从 InsertEnter/CmdlineEnter 提前到 lazy.setup 末尾。
					-- 但 core/lsp.lua 的 VeryLazy autocmd 反正也会强制 require 一次，
					-- 等价开销。
					capabilities = require("core.lsp").make_capabilities(),
					default_settings = {
						["rust-analyzer"] = {
							-- 保存时跑 clippy（替代默认的 cargo check），lint
							-- 警告走 LSP diagnostics。Rust 圈 de-facto 标配。
							-- 性能注意：大项目 clippy 慢 → 改回 "check"。
							check = {
								command = "clippy",
								extraArgs = { "--", "-D", "warnings" },
							},
							cargo = {
								allFeatures = false, -- 只编当前 features；要全 features 改 true（编译变慢）
								loadOutDirsFromCheck = true,
								buildScripts = { enable = true },
							},
							-- proc-macro 支持（默认开，显式声明防 upstream 改默认）
							procMacro = { enable = true },
							-- inlay hints 由 core/lsp.lua 的 LspAttach 统一开关；这里只调内容
							inlayHints = {
								bindingModeHints = { enable = false },
								chainingHints = { enable = true },
								closingBraceHints = { enable = true, minLines = 25 },
								closureReturnTypeHints = { enable = "never" },
								lifetimeElisionHints = { enable = "never" },
								maxLength = 25,
								parameterHints = { enable = true },
								reborrowHints = { enable = "never" },
								renderColons = true,
								typeHints = {
									enable = true,
									hideClosureInitialization = false,
									hideNamedConstructor = false,
								},
							},
							-- import 风格 —— 跟着 IDE 默认（rust-analyzer 自己挑 std vs core 等）
							imports = {
								granularity = { group = "module" },
								prefix = "self",
							},
							-- 完成项里包含 not-yet-imported 的符号，按 Tab 时自动加 use
							completion = {
								autoimport = { enable = true },
								postfix = { enable = true },
							},
						},
					},
				},
				-- DAP: dap/codelldb.lua 已注册 dap.adapters.codelldb；让出，
				-- 别让 rustaceanvim 覆写。`:RustLsp debuggables` 仍然能用——
				-- 它只是 dap.run({ adapter = "codelldb", ... })，会找到我们的。
				dap = {
					adapter = false,
				},
			}
		end,
	},
}
