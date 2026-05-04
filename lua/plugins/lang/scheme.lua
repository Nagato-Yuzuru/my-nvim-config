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
			-- 动态读 maplocalleader，避免硬编码 ","——如果将来改 localleader，前缀跟着变。
			-- 前缀 = <localleader>c，留出 <localleader>p 给 paredit。
			vim.g["conjure#mapping#prefix"] = vim.g.maplocalleader .. "c"
			-- 仅启用我们关心的客户端，避免无关 ft 被它接管
			vim.g["conjure#filetypes"] = CONJURE_FT
			-- K 保留给 LSP hover（vim.lsp.buf.hover），不让 conjure 覆盖
			vim.g["conjure#mapping#doc_word"] = false
			-- HUD（浮动 popup）保持启用，提供 eval 即时反馈。
			-- 持久 log split 用 <localleader>cls（下）/ <localleader>clv（右）手动开。
			vim.g["conjure#log#botright"] = true

			-- 工具链探测：init 时提前注册 autocmd，第一个 .scm/.rkt 打开时立刻触发。
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("UserSchemeEnsure", { clear = true }),
				pattern = CONJURE_FT,
				callback = function(ev)
					require("tools.scheme_ensure").check_for_ft(vim.bo[ev.buf].filetype)
				end,
			})
		end,
		config = function()
			-- which-key desc：Conjure 内部自己注册键位（无 desc），用 wk.add() 补描述。
			-- PAREDIT_FT 也在这里一并处理（= CONJURE_FT ∪ {lisp}），省一个 autocmd。
			-- vim.schedule 确保 which-key（VeryLazy）已加载再调用 add()。
			local function setup_wk(buf)
				local ok, wk = pcall(require, "which-key")
				if not ok then
					return
				end
				local ft = vim.bo[buf].filetype
				-- gK：raco docs 开浏览器，作为 K（LSP hover）的补充。
				-- <C-k>：手动触发签名提示；racket-langserver 对 Invoked 返回 null，
				-- 实际签名提示靠 blink auto-trigger（输入 space/)/] 时自动弹出）。
				if ft == "racket" then
					vim.keymap.set("n", "gK", function()
						vim.fn.system({ "raco", "docs", "--", vim.fn.expand("<cword>") })
					end, { buffer = buf, silent = true, desc = "Racket: raco docs (browser)" })
				end
				local specs = {
					{ "<localleader>p", group = "Paredit", buffer = buf },
					{ "<localleader>pd", group = "Paredit: Delete", buffer = buf },
				}
				if ft == "racket" then
					vim.list_extend(specs, {
						{ "gK", desc = "Racket: raco docs (browser)", buffer = buf },
					})
				end
				if vim.tbl_contains(CONJURE_FT, ft) then
					vim.list_extend(specs, {
						{ "<localleader>c", group = "Conjure", buffer = buf },
						{ "<localleader>ce", group = "Eval", buffer = buf },
						{ "<localleader>cee", desc = "Eval current form", buffer = buf },
						{ "<localleader>cer", desc = "Eval root form", buffer = buf },
						{ "<localleader>cew", desc = "Eval word", buffer = buf },
						{ "<localleader>cep", desc = "Eval previous", buffer = buf },
						{ "<localleader>cem", desc = "Eval marked form", buffer = buf },
						{ "<localleader>cef", desc = "Eval file", buffer = buf },
						{ "<localleader>ceb", desc = "Eval buffer", buffer = buf },
						{ "<localleader>ce!", desc = "Eval replace form", buffer = buf },
						{ "<localleader>cE", desc = "Eval motion (operator)", buffer = buf, mode = "n" },
						{ "<localleader>cE", desc = "Eval visual", buffer = buf, mode = "v" },
						{ "<localleader>cec", group = "Eval (comment)", buffer = buf },
						{ "<localleader>cece", desc = "Eval current form (comment)", buffer = buf },
						{ "<localleader>cecr", desc = "Eval root form (comment)", buffer = buf },
						{ "<localleader>cecw", desc = "Eval word (comment)", buffer = buf },
						{ "<localleader>cc", group = "REPL", buffer = buf },
						{ "<localleader>ccs", desc = "REPL: start", buffer = buf },
						{ "<localleader>ccS", desc = "REPL: stop", buffer = buf },
						{ "<localleader>cg", group = "Navigate", buffer = buf },
						{ "<localleader>cgd", desc = "Go to definition", buffer = buf },
						{ "<localleader>cl", group = "Log", buffer = buf },
						{ "<localleader>cls", desc = "Log: split", buffer = buf },
						{ "<localleader>clv", desc = "Log: vsplit", buffer = buf },
						{ "<localleader>clt", desc = "Log: tab", buffer = buf },
						{ "<localleader>cle", desc = "Log: buffer", buffer = buf },
						{ "<localleader>clg", desc = "Log: toggle", buffer = buf },
						{ "<localleader>clq", desc = "Log: close", buffer = buf },
						{ "<localleader>cll", desc = "Log: jump to latest", buffer = buf },
						{ "<localleader>clr", desc = "Log: soft reset", buffer = buf },
						{ "<localleader>clR", desc = "Log: hard reset", buffer = buf },
					})
				end
				wk.add(specs)
			end

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("UserSchemeWK", { clear = true }),
				pattern = PAREDIT_FT,
				callback = function(ev)
					vim.schedule(function()
						setup_wk(ev.buf)
					end)
				end,
			})
			-- 已打开的 buffer（触发插件加载的那个）
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.tbl_contains(PAREDIT_FT, vim.bo[buf].filetype) then
					vim.schedule(function()
						setup_wk(buf)
					end)
				end
			end
		end,
	},

	-- 2) nvim-paredit — 结构化括号编辑
	--
	-- use_default_keys = false：完全由下面的 keys 表控制，避免默认键（如
	-- <localleader>@ splice、<localleader>o/O raise）漏进 which-key。
	-- 之前用 opts={keys={...string...}} 是错的：api 引用必须是函数，opts 函数
	-- 在插件加载后才调用，这时 require("nvim-paredit.api") 才可用。
	{
		"julienvincent/nvim-paredit",
		ft = PAREDIT_FT,
		config = function()
			local api = require("nvim-paredit.api")
			local no = { repeatable = false }
			local no_nxov = vim.tbl_extend("force", no, { mode = { "n", "x", "o", "v" } })
			local no_nxv = vim.tbl_extend("force", no, { mode = { "n", "x", "v" } })
			local no_ov = vim.tbl_extend("force", no, { mode = { "o", "v" } })

			require("nvim-paredit").setup({
				use_default_keys = false,
				filetypes = PAREDIT_FT,
				keys = {
					-- 结构编辑：全部在 <localleader>p 下
					-- slurp = 把相邻兄弟元素吸进括号；barf = 把括号内元素推出去
					["<localleader>p>"] = { api.slurp_forwards, "Slurp forwards (absorb next sibling)" },
					["<localleader>p<"] = { api.barf_forwards, "Barf forwards (expel last element)" },
					["<localleader>pP"] = { api.slurp_backwards, "Slurp backwards (absorb prev sibling)" },
					["<localleader>pB"] = { api.barf_backwards, "Barf backwards (expel first element)" },
					["<localleader>pw"] = { api.wrap_element_under_cursor, "Wrap element in ()" },
					["<localleader>pW"] = { api.wrap_enclosing_form_under_cursor, "Wrap enclosing form in ()" },
					["<localleader>pr"] = {
						api.raise_element,
						"Raise element (replace parent with element)",
					},
					["<localleader>pR"] = { api.raise_form, "Raise form (replace parent with form)" },
					["<localleader>pS"] = {
						api.unwrap_form_under_cursor,
						"Splice (remove delimiters, keep contents)",
					},
					["<localleader>pdf"] = { api.delete_form, "Delete form" },
					["<localleader>pde"] = { api.delete_element, "Delete element" },

					-- 拖拽：在兄弟列表内移动元素/pair/form（>/<前缀，vim 风格）
					[">e"] = { api.drag_element_forwards, "Drag element right" },
					["<e"] = { api.drag_element_backwards, "Drag element left" },
					[">p"] = { api.drag_pair_forwards, "Drag pair right" },
					["<p"] = { api.drag_pair_backwards, "Drag pair left" },
					[">f"] = { api.drag_form_forwards, "Drag form right" },
					["<f"] = { api.drag_form_backwards, "Drag form left" },

					-- 导航：E/W/B/gE 比 vim 的 w/b 在嵌套结构里精确
					["E"] = vim.tbl_extend("force", { api.move_to_next_element_tail, "Next element tail" }, no_nxov),
					["W"] = vim.tbl_extend("force", { api.move_to_next_element_head, "Next element head" }, no_nxov),
					["B"] = vim.tbl_extend("force", { api.move_to_prev_element_head, "Prev element head" }, no_nxov),
					["gE"] = vim.tbl_extend("force", { api.move_to_prev_element_tail, "Prev element tail" }, no_nxov),
					["("] = vim.tbl_extend("force", { api.move_to_parent_form_start, "Parent form start" }, no_nxv),
					[")"] = vim.tbl_extend("force", { api.move_to_parent_form_end, "Parent form end" }, no_nxv),

					-- 文本对象：af/if form，aF/iF 顶层 form，ae/ie element
					["af"] = vim.tbl_extend("force", { api.select_around_form, "Around form" }, no_ov),
					["if"] = vim.tbl_extend("force", { api.select_in_form, "In form" }, no_ov),
					["aF"] = vim.tbl_extend(
						"force",
						{ api.select_around_top_level_form, "Around top-level form" },
						no_ov
					),
					["iF"] = vim.tbl_extend("force", { api.select_in_top_level_form, "In top-level form" }, no_ov),
					["ae"] = vim.tbl_extend("force", { api.select_element, "Around element" }, no_ov),
					["ie"] = vim.tbl_extend("force", { api.select_element, "In element" }, no_ov),
				},
			})
		end,
	},
}
