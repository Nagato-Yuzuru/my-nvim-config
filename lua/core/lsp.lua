-- 全局 LSP 配置：capabilities / enable / LspAttach keymaps
-- 所有 per-server 配置在顶层 lsp/*.lua，由 vim.lsp.enable() 自动加载。
-- 例外：rust-analyzer 由 rustaceanvim 接管（见 plugins/lang/rust.lua），
-- 不在 vim.lsp.enable 列表里，顶层 lsp/rust_analyzer.lua 也已删除。

local M = {}

-- 构造与项目里所有 LSP 客户端共享的 capabilities：
--   * blink.cmp 的补全 caps（强制 require —— 装不进来是真故障，不 pcall 吞掉）
--   * nvim-ufo 要求的 lineFoldingOnly（否则 jsonls / yamlls 等服务端不会返回 foldingRange）
-- 同时被下面的 VeryLazy `vim.lsp.config("*", ...)` 和 rustaceanvim 的
-- `server.capabilities`（在 plugins/lang/rust.lua）复用 —— 避免两份独立的
-- caps 构造逻辑。rustaceanvim 自己 `vim.lsp.start()` 启动 rust-analyzer，
-- **不**走 `vim.lsp.config("*")`，所以必须显式塞 caps 进去。
function M.make_capabilities()
	local caps = vim.tbl_deep_extend(
		"force",
		vim.lsp.protocol.make_client_capabilities(),
		require("blink.cmp").get_lsp_capabilities()
	)
	caps.textDocument = caps.textDocument or {}
	caps.textDocument.foldingRange = {
		dynamicRegistration = false,
		lineFoldingOnly = true,
	}
	return caps
end

-- 全局 capabilities（VeryLazy 时 blink.cmp 已加载）
vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	once = true,
	callback = function()
		vim.lsp.config("*", { capabilities = M.make_capabilities() })

		-- 关掉 Neovim 0.11+ 内核自带的 gr*/gO LSP 默认键。
		-- 我们已有 gd/gi/gD + <leader>rn/<leader>ca/<leader>vs 等价物（见 CLAUDE.md
		-- "Navigation g* — two intentional decisions"），留着只会让 `gr`（Trouble
		-- references, 见 plugins/ui/trouble.lua）每次都要等 timeoutlen 消歧。
		-- 注意：这些默认是 **全局** 映射（:nmap gr 输出无 `@` 标记），删除时
		-- 不能传 { buffer = ... }。pcall 兜底，因为不同 nvim 版本 gr* 集合会变
		-- （grx codelens 是 0.11 后期才加的）。
		for _, lhs in ipairs({ "grn", "gra", "grr", "gri", "grt", "grx" }) do
			pcall(vim.keymap.del, "n", lhs)
		end
		pcall(vim.keymap.del, "x", "gra")
		pcall(vim.keymap.del, "n", "gO")
	end,
})

-- Hover popup buffer 内把 K 绑为关闭 popup：
-- 默认 hover popup 没挂 LspAttach，K 会回落到 keywordprg (:help)。虽然我们已
-- 经把 keywordprg 从 :Man 改成 :help（见 core/options.lua），popup 里按 K 跳
-- 出一个 no-help 提示仍然不直觉。更符合直觉的是"再按一次 K 关掉 popup"。
do
	local orig = vim.lsp.util.open_floating_preview
	vim.lsp.util.open_floating_preview = function(contents, syntax, opts, ...)
		local bufnr, winid = orig(contents, syntax, opts, ...)
		if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
			vim.keymap.set("n", "K", function()
				if winid and vim.api.nvim_win_is_valid(winid) then
					vim.api.nvim_win_close(winid, true)
				end
			end, { buffer = bufnr, silent = true, desc = "Close hover popup" })
		end
		return bufnr, winid
	end
end

-- 启用 LSP servers
vim.lsp.enable({
	"lua_ls",
	"pyright",
	"ruff",
	"ty",
	"gopls",
	"jsonls",
	"yamlls",
	"bashls",
	"taplo",
	"marksman",
	"terraformls",
	"dockerls",
	"clangd",
	"just_ls",
	"denols",
	"vtsls",
	"eslint",
	"helm_ls",
	-- rust_analyzer 由 rustaceanvim 接管（见 plugins/lang/rust.lua）
	"tinymist",
})

-- Scheme 系 LSP 按需启用——后端不在时不挂，避免刷 "Client X quit with exit code 1"。
-- 工具链探测在 lua/tools/scheme_ensure.lua；FileType 触发的安装提示也走那里。
-- 装好工具后重启一次 nvim 就会启用对应 LSP（同一 session 内不动态启用，因为
-- 探测结果已缓存且这个场景不值得做热重载）。
do
	local ensure = require("tools.scheme_ensure")
	if ensure.is_installed("racket-langserver (raco pkg)") then
		vim.lsp.enable("racket_langserver")
	end
	if ensure.is_installed("guile-lsp-server") then
		vim.lsp.enable("guile_lsp_server")
	end
	if ensure.is_installed("steel-language-server") then
		vim.lsp.enable("steel_language_server")
	end
end

-- Codelens 自动刷新的 augroup（按 buffer 注册 autocmd，模块级声明便于二次 attach 时复用）。
local codelens_augroup = vim.api.nvim_create_augroup("UserLspCodelens", { clear = true })

-- LspAttach: 快捷键 + inlay hints
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspKeymaps", { clear = true }),
	callback = function(args)
		local bufnr = args.buf
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		local map = function(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, noremap = true, silent = true, desc = desc })
		end
		-- Only register a keymap if the attached server supports the method.
		local map_if = function(method, mode, lhs, rhs, desc)
			if client and client:supports_method(method) then
				map(mode, lhs, rhs, desc)
			end
		end

		pcall(function()
			vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
		end)

		-- K 必须显式绑定：ftplugin（如 racket.vim 把 K 映射到 raco docs）在
		-- FileType 时先跑，会把 Neovim 0.11 的默认覆盖掉。LspAttach 在 FileType
		-- 之后触发，这里显式 set 就能盖回来。
		map("n", "K", vim.lsp.buf.hover, "LSP: Hover")
		-- racket-langserver 对手动触发（Invoked）返回 null——只有 blink 在输入
		-- 触发字符（space / ) / ]）时的 auto-trigger 有签名提示。
		-- #lang sicp 完全没有签名提示：server 不支持该方言的 signatureHelp。
		map("i", "<C-k>", vim.lsp.buf.signature_help, "LSP: Signature Help")
		-- Navigation: g* follows community defaults (mirrors .ideavimrc §Navigation).
		-- gd: Goto Definition    | gD: Goto Type Definition
		-- gi: Goto Implementation | gr: References (Trouble UI, see ui/trouble.lua)
		-- Note: gD overrides vim.lsp.buf.declaration — declaration is rarely
		--       distinct from definition for our stack; type-def is more useful.
		map("n", "gd", vim.lsp.buf.definition, "Goto Definition")
		map("n", "gD", vim.lsp.buf.type_definition, "Goto Type Definition")
		map("n", "gi", vim.lsp.buf.implementation, "Goto Implementation")
		-- Refactor 命名空间。**只绑 LSP CodeActionKind 真正能区分的入口**——
		-- 不为缺粒度的 IdeaVim 动作做语义重复的 alias（绑 6 个键到同一个 extract
		-- 菜单算 muscle-memory 假象，不实质）。LSP 标准 kind 只有 4 层：
		-- refactor / refactor.extract / refactor.inline / refactor.rewrite，对应：
		--
		-- 故意不绑（接受 IdeaVim 与 LSP 的能力差）：
		--   <leader>r{v,c,f,m,i,p}（IntroduceVariable / Constant / Field /
		--     ExtractMethod / Interface / Parameter）—— LSP 都归 refactor.extract
		--     一层，无法键级直达；想要这些请走 <leader>re 后从菜单里挑
		--   <leader>rs (ChangeSignature) —— LSP 无专门 kind，server 散落在
		--     refactor.rewrite，gopls 当前也不暴露；想要请走 <leader>rr 主菜单
		--   <leader>rd / rj / rM —— LSP 完全无对应物（SafeDelete / Jupyter / Move）
		local refactor_kind = function(only)
			return function()
				vim.lsp.buf.code_action({ context = { only = only, diagnostics = {} } })
			end
		end
		-- <leader>rn 由 inc-rename.nvim 处理（plugins/lsp/inc-rename.lua）
		map_if("textDocument/codeAction", { "n", "x" }, "<leader>re",
			refactor_kind({ "refactor.extract" }), "Refactor: Extract …")
		map_if("textDocument/codeAction", { "n", "x" }, "<leader>rl",
			refactor_kind({ "refactor.inline" }), "Refactor: Inline")
		map_if("textDocument/codeAction", { "n", "x" }, "<leader>rr",
			refactor_kind({ "refactor" }), "Refactor: All …")
		-- <leader>R 是 IdeaVim 的 RefactoringMenu，和 <leader>rr 实质同一个入口；
		-- 两个都保留以对齐 .ideavimrc（IdeaVim 那边也是双键并存）。
		map_if("textDocument/codeAction", { "n", "x" }, "<leader>R",
			refactor_kind({ "refactor" }), "Refactor: All …")
		map("n", "<leader>ca", vim.lsp.buf.code_action, "Code Action")
		-- Codelens：运行光标行的 lens（gopls test runner / rustaceanvim Run|Debug /
		-- vtsls "N references" / clangd parameters 等）。代替了上游被我们关掉的 `grx`。
		-- IdeaVim 侧无对应键——JetBrains 的 lens 走 gutter 图标 + IDE Run/Debug 快捷键
		-- (Shift+F10 等)，不通过 IdeaVim mapping。这是 CLAUDE.md 允许的"genuinely
		-- nvim-only"非对称项。
		map_if("textDocument/codeLens", "n", "<leader>cl", vim.lsp.codelens.run, "Run Code Lens")
		-- <leader>n* — extras that have no standard g* counterpart:
		map_if("textDocument/prepareTypeHierarchy", "n", "<leader>nb", function()
			vim.lsp.buf.typehierarchy("supertypes")
		end, "Goto Base (supertypes)")

		-- Codelens auto-refresh：没有 refresh 调用的话 virtual_text 不会渲染，<leader>cl
		-- 也就没东西可跑。BufEnter/InsertLeave/BufWritePost 是社区惯用的触发集——覆盖
		-- 打开 / 编辑后离开插入 / 保存三种修改契机，**故意避开 CursorHold**（updatetime
		-- 一低就是高频抖动，对大型 TS 项目会让 vtsls 闷到冒烟）。
		if client and client:supports_method("textDocument/codeLens") then
			vim.api.nvim_clear_autocmds({ group = codelens_augroup, buffer = bufnr })
			vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
				group = codelens_augroup,
				buffer = bufnr,
				callback = function()
					vim.lsp.codelens.refresh({ bufnr = bufnr })
				end,
			})
			vim.lsp.codelens.refresh({ bufnr = bufnr })
		end
	end,
})

return M
