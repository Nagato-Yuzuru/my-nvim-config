-- 全局 LSP 配置：capabilities / enable / LspAttach keymaps
-- 所有 per-server 配置在顶层 lsp/*.lua，由 vim.lsp.enable() 自动加载

-- 全局 capabilities（VeryLazy 后 blink.cmp 已加载）
vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	once = true,
	callback = function()
		local caps = vim.lsp.protocol.make_client_capabilities()
		pcall(function()
			caps = vim.tbl_deep_extend("force", caps, require("blink.cmp").get_lsp_capabilities())
		end)
		-- nvim-ufo 的 LSP provider 要求显式声明 lineFoldingOnly，
		-- 否则 jsonls / yamlls 等服务端不会返回 foldingRange。
		caps.textDocument = caps.textDocument or {}
		caps.textDocument.foldingRange = {
			dynamicRegistration = false,
			lineFoldingOnly = true,
		}
		vim.lsp.config("*", { capabilities = caps })
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
	"rust_analyzer",
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

		-- Hover (K) and insert-mode signature_help (<C-k>) follow Neovim 0.11
		-- LspAttach community defaults. The signature_help line below is kept
		-- explicit as a safety net against upstream default changes; it is NOT
		-- a divergence from the default.
		map("i", "<C-k>", vim.lsp.buf.signature_help, "LSP: Signature Help")
		-- Navigation: g* follows community defaults (mirrors .ideavimrc §Navigation).
		-- gd: Goto Definition    | gD: Goto Type Definition
		-- gi: Goto Implementation | gr: References (Trouble UI, see ui/trouble.lua)
		-- Note: gD overrides vim.lsp.buf.declaration — declaration is rarely
		--       distinct from definition for our stack; type-def is more useful.
		map("n", "gd", vim.lsp.buf.definition, "Goto Definition")
		map("n", "gD", vim.lsp.buf.type_definition, "Goto Type Definition")
		map("n", "gi", vim.lsp.buf.implementation, "Goto Implementation")
		-- <leader>rn is handled by inc-rename.nvim (plugins/lsp/inc-rename.lua)
		map("n", "<leader>ca", vim.lsp.buf.code_action, "Code Action")
		-- <leader>n* — extras that have no standard g* counterpart:
		map_if("textDocument/prepareTypeHierarchy", "n", "<leader>nb", function()
			vim.lsp.buf.typehierarchy("supertypes")
		end, "Goto Base (supertypes)")
	end,
})
