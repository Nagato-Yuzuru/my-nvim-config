-- Scheme / Racket / Steel 插件层。
--
-- 工具链定位（和 spec 里一致）：
--   - Racket  → SICP 主力 + 日常 Scheme（lsp/racket_langserver.lua）
--   - Guile   → Hoot (Guile→WASM) 阅读环境（lsp/guile_lsp_server.lua）
--   - Steel   → Rust 嵌入式 Scheme，最贴近 transpiler 项目（lsp/steel_language_server.lua）
--
-- 这里只装"编辑体验三件套"——Lisp 工作流离不开它们：
--   1. conjure       结构化 REPL 交互（,c* 前缀）
--   2. nvim-paredit  括号 slurp/barf/wrap（,p* 前缀）
--   3. tree-sitter   高亮 / 文本对象 / rainbow（解析器在 plugins/treesitter.lua）
--
-- DAP / neotest 不接：Lisp 工作流走 REPL 而不是断点。详见
--   docs/superpowers/specs/2026-04-29-scheme-toolchain-design.md
--
-- conform 自定义 formatter（raco_fmt / schemat）的定义在 plugins/format/conform.lua
-- 里——和 mdformat 同一个地方，避免 scheme 这边再去 patch conform.formatters。

-- conjure 只接管 scheme/racket（Steel/Guile 也走 scheme ft）；paredit 多管
-- 一个 lisp 是值的（Common Lisp 缩括号/slurp/barf 同样有用），但让 conjure
-- 在 .lisp 上 require 进来纯属浪费——它会立刻看 conjure#filetypes 然后什么都
-- 不做。两侧分开。
local CONJURE_FT = { "scheme", "racket" }
local PAREDIT_FT = { "scheme", "racket", "lisp" }

return {
	-- 1) Conjure — REPL 交互层，Lisp 系工作流的核心
	{
		"Olical/conjure",
		ft = CONJURE_FT,
		init = function()
			-- 把 conjure 默认 <localleader>* 前缀整体收进 ,c*，留出 ,p* 给 paredit、
			-- ,t* 给将来的测试 runner 等。<localleader> = "," 已在 init.lua 设好。
			vim.g["conjure#mapping#prefix"] = ",c"
			-- 仅启用我们关心的三个客户端，避免无关 ft 被它接管
			vim.g["conjure#filetypes"] = CONJURE_FT
			-- 不要在 lisp buffer 里覆盖 K，让 nvim 原生 hover 走 LSP（K = vim.lsp.buf.hover）
			vim.g["conjure#mapping#doc_word"] = false
			-- log buffer 默认垂直右开，宽屏更舒服
			vim.g["conjure#log#botright"] = true

			-- 顺手挂上 scheme 工具链探测——init 在 startup 时跑，autocmd 提前注册，
			-- 第一个 .scm/.rkt 打开时立刻触发，比放到 conjure 的 config 里更可靠
			-- （后者要等 conjure 真的加载完）。
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("UserSchemeEnsure", { clear = true }),
				pattern = CONJURE_FT,
				callback = function(ev)
					require("tools.scheme_ensure").check_for_ft(vim.bo[ev.buf].filetype)
				end,
			})
		end,
	},

	-- 2) nvim-paredit — 结构化括号编辑
	{
		"julienvincent/nvim-paredit",
		ft = PAREDIT_FT,
		opts = {
			-- 把所有 paredit 操作收进 ,p* 子前缀（buffer-local，由插件自己挂）。
			-- 默认 keys 大量占用 <localleader>>/< 等单符号，会和 conjure 撞。
			keys = {
				[",p>"] = { "api.slurp_forwards", "Slurp forwards" },
				[",p<"] = { "api.barf_forwards", "Barf forwards" },
				[",pP"] = { "api.slurp_backwards", "Slurp backwards" },
				[",pB"] = { "api.barf_backwards", "Barf backwards" },
				[",pw"] = { "api.wrap.wrap_element_under_cursor", "Wrap element" },
				[",pW"] = { "api.wrap.wrap_enclosing_form_under_cursor", "Wrap enclosing form" },
				[",pr"] = { "api.raise_element", "Raise element" },
				[",pR"] = { "api.raise_form", "Raise form" },
				[",pdf"] = { "api.delete_form", "Delete form" },
				[",pde"] = { "api.delete_element", "Delete element" },
				-- 移动到下一/上一 element / form——比 vim 的 W/B 在嵌套结构里精确得多
				["E"] = { "api.move_to_next_element_tail", "Next element tail" },
				["W"] = { "api.move_to_next_element_head", "Next element head" },
				["B"] = { "api.move_to_prev_element_head", "Prev element head" },
				["gE"] = { "api.move_to_prev_element_tail", "Prev element tail" },
				["("] = { "api.move_to_parent_form_start", "Parent form start" },
				[")"] = { "api.move_to_parent_form_end", "Parent form end" },
			},
			-- 这些 ft 启用 paredit 的 buffer-local 操作
			filetypes = PAREDIT_FT,
		},
	},
}
