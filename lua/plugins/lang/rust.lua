-- Rust 专属 nvim 集成
--
-- crates.nvim：Cargo.toml 里 hover 看 crate 信息、显示最新版本、一键升级、补全。
-- 编辑 Cargo.toml 必备（rust-analyzer 不管 Cargo.toml 本身的 UX）。
--
-- LSP / Test / DAP 不在这里：
--   - LSP    → lsp/rust_analyzer.lua
--   - Test   → plugins/runtime/neotest.lua（neotest-rust 自动检测 cargo-nextest）
--   - DAP    → dap/codelldb.lua（filetypes 含 "rust"）

return {
	{
		"saecki/crates.nvim",
		event = { "BufRead Cargo.toml" },
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
				actions = true,    -- code actions: upgrade / open docs.rs
				completion = true, -- blink.cmp 走 LSP 渠道吃 crates 的补全
				hover = true,      -- K 显示 crate 信息
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
		keys = {
			-- 用 buffer-local autocmd 注册键，避免污染非 Cargo.toml buffer
			-- 这里给的是触发键（lazy.nvim keys），buffer 局部映射在 config 时注册
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
}
