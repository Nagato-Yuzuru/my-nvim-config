-- Scheme / Racket / Steel 插件层。
--
-- 工具链定位（和 spec 里一致）：
--   - Racket  → SICP 主力 + 日常 Scheme（lsp/racket_langserver.lua）
--   - Guile   → Hoot (Guile→WASM) 阅读环境（lsp/guile_lsp_server.lua）
--   - Steel   → Rust 嵌入式 Scheme，最贴近 transpiler 项目（lsp/steel_language_server.lua）
--
-- 这里只装"编辑体验三件套"——Lisp 工作流离不开它们：
--   1. conjure       结构化 REPL 交互（裸 <localleader> 前缀，键位对齐 Conjure 文档）
--   2. nvim-paredit  括号 slurp/barf/wrap（<localleader>p 前缀 + 结构导航/文本对象）
--   3. tree-sitter   高亮 / 文本对象 / rainbow（解析器在 plugins/treesitter.lua）
--
-- 键位分工（都是 buffer-local，只活在 scheme/racket/lisp）：
--   * Conjure 走裸 <localleader>：Eval ,e* / Log ,l* / REPL ,c{s,S} / Goto ,gd
--     ——和 Conjure 教程逐键一致（不再套一层 c）。首键只用 e/l/c/g，不撞 paredit。
--   * paredit 结构编辑走 <localleader>p*；drag 用 canonical >{e,p,f} / <{e,p,f}
--     （只遮蔽 scheme buffer 里极冷门的 `>{e,p,f}` 缩进组合，换取查表一致）。
--   * 结构导航走 vim 的 [ / ] 家族（]e/[e 元素）；父 form 首/尾用 vim 原生 [( / ])，
--     兄弟/父/子交给 treewalker（<leader>n{h,j,k,l}）——都不遮蔽 W/E/B。
--
-- DAP / neotest 不接：Lisp 工作流走 REPL 而不是断点。
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
			-- 不设 conjure#mapping#prefix：回落到 Conjure 默认 "<localleader>"，键位和官方
			-- 文档/教程 1:1（学习期查表即用）。它本就随 maplocalleader 动态解析，无需硬编码。
			-- paredit 独占 <localleader>p，不撞——Conjure 首键只用 e/l/c/g（eval/log/REPL/goto）。
			-- 仅启用我们关心的客户端，避免无关 ft 被它接管
			vim.g["conjure#filetypes"] = CONJURE_FT
			-- REPL 只在显式 <localleader>cs 时启动。Conjure 默认 client_on_load=true
			-- 会在打开任何 racket/scheme buffer 时就静默 spawn 一个解释器子进程——
			-- 只是浏览代码也白跑一个 racket，多实例/多文件时 ps 里一排来历不明的
			-- 进程，且用户从未要求过 REPL。
			vim.g["conjure#client_on_load"] = false
			-- NOTE(REPL 后端未接)：.scm（scheme ft）当前仍走 Conjure 默认 client——命令是
			-- mit-scheme（没装、也不是本工具链的 Guile/Steel），故 <localleader>cs 在 .scm
			-- 里会失败。等真正用 Guile/Steel REPL 时再设 conjure#client#scheme#stdio#command
			-- ＋匹配的 prompt_pattern（Guile 提示符形如 "scheme@(guile-user)>"）。.rkt（racket
			-- ft）不受影响：走 racket client，命令就是已安装的 `racket`。
			-- K 保留给 LSP hover（vim.lsp.buf.hover），不让 conjure 覆盖
			vim.g["conjure#mapping#doc_word"] = false
			-- HUD（浮动 popup）保持启用，提供 eval 即时反馈。
			-- 持久 log split 用 <localleader>ls（下）/ <localleader>lv（右）手动开。
			vim.g["conjure#log#botright"] = true

			-- 工具链探测：init 时提前注册 autocmd，第一个 .scm/.rkt 打开时立刻触发。
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("UserSchemeEnsure", { clear = true }),
				pattern = CONJURE_FT,
				callback = function(ev) require("tools.scheme_toolchain").check_for_ft(vim.bo[ev.buf].filetype) end,
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
					vim.keymap.set(
						"n",
						"gK",
						function() vim.fn.system({ "raco", "docs", "--", vim.fn.expand("<cword>") }) end,
						{ buffer = buf, silent = true, desc = "Racket: raco docs (browser)" }
					)
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
					-- Conjure 注册键位时不带 desc，这里补上。键 = Conjure 默认后缀，前缀是
					-- 裸 <localleader>。分组按动作：Eval / Log / REPL / Goto。
					vim.list_extend(specs, {
						{ "<localleader>e", group = "Eval", buffer = buf },
						{ "<localleader>ee", desc = "Eval current form", buffer = buf },
						{ "<localleader>er", desc = "Eval root form", buffer = buf },
						{ "<localleader>ew", desc = "Eval word", buffer = buf },
						{ "<localleader>ep", desc = "Eval previous", buffer = buf },
						{ "<localleader>em", desc = "Eval marked form", buffer = buf },
						{ "<localleader>ef", desc = "Eval file", buffer = buf },
						{ "<localleader>eb", desc = "Eval buffer", buffer = buf },
						{ "<localleader>e!", desc = "Eval replace form", buffer = buf },
						{ "<localleader>ei", desc = "Interrupt REPL", buffer = buf },
						{ "<localleader>E", desc = "Eval motion (operator)", buffer = buf, mode = "n" },
						{ "<localleader>E", desc = "Eval visual", buffer = buf, mode = "v" },
						{ "<localleader>ec", group = "Eval (comment)", buffer = buf },
						{ "<localleader>ece", desc = "Eval current form (comment)", buffer = buf },
						{ "<localleader>ecr", desc = "Eval root form (comment)", buffer = buf },
						{ "<localleader>ecw", desc = "Eval word (comment)", buffer = buf },
						{ "<localleader>c", group = "REPL", buffer = buf },
						{ "<localleader>cs", desc = "REPL: start", buffer = buf },
						{ "<localleader>cS", desc = "REPL: stop", buffer = buf },
						{ "<localleader>g", group = "Goto", buffer = buf },
						{ "<localleader>gd", desc = "Go to definition", buffer = buf },
						{ "<localleader>l", group = "Log", buffer = buf },
						{ "<localleader>ls", desc = "Log: split", buffer = buf },
						{ "<localleader>lv", desc = "Log: vsplit", buffer = buf },
						{ "<localleader>lt", desc = "Log: tab", buffer = buf },
						{ "<localleader>le", desc = "Log: buffer", buffer = buf },
						{ "<localleader>lg", desc = "Log: toggle", buffer = buf },
						{ "<localleader>lq", desc = "Log: close visible", buffer = buf },
						{ "<localleader>ll", desc = "Log: jump to latest", buffer = buf },
						{ "<localleader>lr", desc = "Log: soft reset", buffer = buf },
						{ "<localleader>lR", desc = "Log: hard reset", buffer = buf },
					})
				end
				wk.add(specs)
			end

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("UserSchemeWK", { clear = true }),
				pattern = PAREDIT_FT,
				callback = function(ev)
					vim.schedule(function() setup_wk(ev.buf) end)
				end,
			})
			-- 已打开的 buffer（触发插件加载的那个）
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.tbl_contains(PAREDIT_FT, vim.bo[buf].filetype) then
					vim.schedule(function() setup_wk(buf) end)
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
					["<localleader>ps"] = {
						api.unwrap_form_under_cursor,
						"Splice (remove delimiters, keep contents)",
					},
					["<localleader>pdf"] = { api.delete_form, "Delete form" },
					["<localleader>pde"] = { api.delete_element, "Delete element" },

					-- 拖拽：在兄弟列表内移动元素/pair/form。用 canonical >{e,p,f}/<{e,p,f}
					-- （只遮蔽 scheme buffer 里极冷门的 `>{e,p,f}` 缩进组合，换查表一致）。
					[">e"] = { api.drag_element_forwards, "Drag element right" },
					["<e"] = { api.drag_element_backwards, "Drag element left" },
					[">p"] = { api.drag_pair_forwards, "Drag pair right" },
					["<p"] = { api.drag_pair_backwards, "Drag pair left" },
					[">f"] = { api.drag_form_forwards, "Drag form right" },
					["<f"] = { api.drag_form_backwards, "Drag form left" },

					-- 结构导航搬到 vim 的 [ / ] 家族，不再遮蔽 W/E/B/gE 的 WORD 动作。
					-- 含 o 模式 → d]e（删到下一个 element）可用。父 form 首/尾用 vim 原生
					-- [( / ])，兄弟/父/子交给 treewalker——都不在此绑。
					["]e"] = vim.tbl_extend("force", { api.move_to_next_element_head, "Next element" }, no_nxov),
					["[e"] = vim.tbl_extend("force", { api.move_to_prev_element_head, "Prev element" }, no_nxov),
					["]E"] = vim.tbl_extend("force", { api.move_to_next_element_tail, "Next element tail" }, no_nxov),
					["[E"] = vim.tbl_extend("force", { api.move_to_prev_element_tail, "Prev element tail" }, no_nxov),

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
