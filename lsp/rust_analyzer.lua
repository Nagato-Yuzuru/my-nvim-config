-- rust-analyzer
--
-- 假设 toolchain 由 rustup 管理（rustup component add rust-analyzer rustfmt clippy）。
-- mason 也提供 rust-analyzer 作为兜底（mason_ensure.LSP_TOOLS 里有），但 rustup
-- 那个版本跟当前激活 toolchain 同步，更可靠。

return {
	cmd = { "rust-analyzer" },
	filetypes = { "rust" },
	root_markers = { "Cargo.toml", "rust-project.json", ".git" },
	settings = {
		["rust-analyzer"] = {
			-- 保存时跑 clippy（替代默认的 cargo check），lint 警告走 LSP diagnostics。
			-- 这是 Rust 圈的 de-facto 标配；clippy 严格但极有教育意义。
			check = {
				command = "clippy",
				extraArgs = { "--", "-D", "warnings" },
			},
			-- 性能：cargo check 在大项目可能拖；如果 lint 反应慢可改回 "check"。
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
}
