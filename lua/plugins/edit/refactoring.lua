---
--- refactoring.nvim — treesitter-based 跨语言重构
--- 填补 LSP CodeActionKind 粒度不足的空白：LSP 只有 refactor.extract 一层，
--- 区分不出"提取函数 / 提取变量 / 提取到新文件"；refactoring.nvim 用
--- treesitter 静态分析，对它支持的语言（JS/TS/Lua/Python/Go/C/C++/Java/
--- Ruby/PHP）能直接给到键级粒度。
---
--- 与 LSP refactor 的分工（详见 lua/core/lsp.lua "Refactor 命名空间" 注释）：
---   refactoring.nvim → extract 三连（treesitter，提供 LSP 没有的键级粒度）
---   LSP code action  → refactor.{inline,rewrite,move} + 全菜单
---   inc-rename       → rename（lua/plugins/lsp/inc-rename.lua）
---
--- <leader>rl 是 LSP-first 自动 fallback 调度器（见 lsp_inline_then_treesitter）：
--- 先 buf_request_all 查 refactor.inline 类 code action，任意 server 有就走
--- nvim 原生 picker；全空才 feedkeys 给 refactoring.nvim 的 inline_var 兜底。
--- 双 RTT 代价 ~150-300ms，换取"按一个键、永远能用"。
---
--- API 说明：refactoring.nvim 用 operatorfunc 模式 —— 函数返回 "g@"，
--- 通过 `expr = true` 让 nvim 接管 motion/textobject。这样同一个键在
--- normal 模式下可以接 textobject（如 `<leader>rmiw`），visual 模式下
--- 直接对选区生效。所有键 mode 都是 {"n","x"}。
---
--- IdeaVim 侧 <leader>r{v,c,f,m,p,i} 在 IDE 里是六个独立动作；refactoring.nvim
--- 只在概念上重合 m=ExtractMethod / v=IntroduceVariable，其余（Constant /
--- IntroduceField / Parameter / ExtractInterface）没有对应物，**按 parity 原则
--- 保持留空**而不是挂个错位语义（同键不同义比缺键更伤肌肉记忆）。
---

local function expr_keymap(lhs, fn_name, desc)
	return {
		lhs,
		function()
			return require("refactoring")[fn_name]()
		end,
		mode = { "n", "x" },
		expr = true,
		desc = desc,
	}
end

-- LSP-first inline 调度器：异步问 attached LSP 有没有 refactor.inline kind 的
-- code action，有就让 nvim 原生 picker 接管；空了再 feedkeys refactoring.nvim
-- 的 inline_var 兜底（"g@l" expr-keymap 走 operatorfunc 流程）。
--
-- mode 处理：
--   - visual: 键被消耗后 visual mode 已退出，'< '> marks 仍记得选区。
--     make_given_range_params(nil, nil, bufnr, enc) 默认就用 last visual。
--     LSP 命中后要 `gv` 重新进 visual 再 buf.code_action，否则它用 cursor pos。
--   - normal: cursor 位置参数即可。
--
-- 双 RTT：pre-query 是为了"判断空与否"，命中后再调 vim.lsp.buf.code_action 走
-- 标准 picker 路径（少自己实现 apply/resolve/command 等坑）。
local function lsp_inline_then_treesitter()
	local mode = vim.api.nvim_get_mode().mode
	local is_visual = mode == "v" or mode == "V" or mode == "\22"
	local bufnr = vim.api.nvim_get_current_buf()

	local fallback = function()
		local keys = require("refactoring").inline_var()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
	end

	local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/codeAction" })
	if #clients == 0 then
		return fallback()
	end

	local enc = clients[1].offset_encoding or "utf-16"
	local params
	if is_visual then
		-- 离开 visual 让 '< '> marks 稳定（visual 中 marks 是动态的）
		vim.cmd("normal! \27")
		params = vim.lsp.util.make_given_range_params(nil, nil, bufnr, enc)
	else
		params = vim.lsp.util.make_range_params(0, enc)
	end
	params.context = { only = { "refactor.inline" }, diagnostics = {} }

	vim.lsp.buf_request_all(bufnr, "textDocument/codeAction", params, function(results)
		local has_action = false
		for _, r in pairs(results or {}) do
			if r.result and #r.result > 0 then
				has_action = true
				break
			end
		end
		vim.schedule(function()
			if has_action then
				if is_visual then
					vim.cmd("normal! gv")
				end
				vim.lsp.buf.code_action({ context = { only = { "refactor.inline" }, diagnostics = {} } })
			else
				fallback()
			end
		end)
	end)
end

return {
	"ThePrimeagen/refactoring.nvim",
	-- 新版 refactoring.nvim（master ≥ 2026-05）改用 lewis6991/async.nvim，
	-- 不再依赖 plenary；treesitter 直接走 nvim 0.12+ 内置 vim.treesitter。
	dependencies = { "lewis6991/async.nvim" },
	---@param opts table
	config = function(_, opts)
		-- 模块名冲突消歧（refactoring.nvim issue #521/522/523）：
		--   * lewis6991/async.nvim 在 lua/async.lua 暴露 `M.wrap`（refactoring 用）
		--   * promise-async（nvim-ufo 的依赖）**同样**提供 lua/async.lua，但暴露的是
		--     一个 *可调用 table*（ufo 写 `async(function() ... end)`）
		-- 两者放进 rtp 后 `require("async")` 谁先到看 package.path 顺序，实测
		-- promise-async 胜出 → refactoring.utils:30 `async.wrap(...)` nil。
		--
		-- 不能用 package.preload 永久劫持——会同时打挂 ufo。利用 Lua "每个文件顶部
		-- `local x = require()` 在加载时捕获 upvalue" 的语义：临时把
		-- package.loaded["async"] 换成 lewis6991 的，强制预加载所有 refactoring 内
		-- 用到 async 的文件（它们的 upvalue 一旦捕获就锁定，与后续 package.loaded
		-- 状态无关），最后还原给 ufo 用。
		local prev_async = package.loaded["async"]
		local lewis_path = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "async.nvim", "lua", "async.lua")
		package.loaded["async"] = assert(loadfile(lewis_path))()

		-- refactoring 里全部 `require "async"` 的源文件（grep 结果，2026-05 master）。
		-- 漏一个会在该路径首次被惰性 require 时复发 wrap=nil。新版若新增文件，
		-- 在这里补全。
		local async_consumers = {
			"refactoring",
			"refactoring.utils",
			"refactoring.refactor.extract_func",
			"refactoring.refactor.extract_var",
			"refactoring.refactor.inline_func",
			"refactoring.refactor.inline_var",
			"refactoring.debug.cleanup",
			"refactoring.debug.print_exp",
			"refactoring.debug.print_loc",
			"refactoring.debug.print_var",
		}
		for _, m in ipairs(async_consumers) do
			require(m)
		end

		require("refactoring").setup(opts)

		-- 还原：ufo 的 require("async") 后续命中 cache 仍是 promise-async 的
		package.loaded["async"] = prev_async
	end,
	keys = {
		-- Extract：refactoring.nvim 用 treesitter 给键级粒度（LSP 把 extract method/
		-- variable/to-file 全归 refactor.extract 一个 kind 进菜单，不细分）。
		--
		-- 故意不绑 <leader>rf：IdeaVim 把它给 IntroduceField（用户常用的 IDE 重构），
		-- nvim 这边无对应物——按 parity 原则"无对应物则留空"，避免把它重新挂给
		-- extract_func_to_file 造成同键不同义的肌肉记忆冲突。需要 extract-to-file
		-- 时走 `:Refactor extract_func_to_file`。
		expr_keymap("<leader>rm", "extract_func", "Refactor: Extract function"),
		expr_keymap("<leader>rv", "extract_var", "Refactor: Extract variable"),
		-- Inline：LSP-first 自动 fallback。<leader>rl 从 lua/core/lsp.lua 搬出来
		-- 由这里统一接管——buffer-local 会盖全局，所以 lsp.lua 那边的同名绑定已删。
		{
			"<leader>rl",
			lsp_inline_then_treesitter,
			mode = { "n", "x" },
			desc = "Refactor: Inline (LSP-first, treesitter fallback)",
		},
	},
	opts = {},
}
