-- 全局 LSP 配置：capabilities / enable / LspAttach keymaps
-- 所有 per-server 配置在顶层 lsp/*.lua，由 vim.lsp.enable() 自动加载。
-- 例外：rust-analyzer 由 rustaceanvim 接管（见 plugins/lang/rust.lua），
-- 不在 vim.lsp.enable 列表里，顶层 lsp/rust_analyzer.lua 也已删除。
--
-- 加载契约：本模块通过 init.lua 在 lazy.setup() **之后** require 并调
-- M.setup()。VeryLazy autocmd 集中由 setup() 注册，顺序对依赖另一个 VeryLazy
-- listener 的旧 mason 配置已不再相关——所有 LSP 相关的 VeryLazy 工作（caps
-- 注入 / mason 装缺失 LSP / 默认键清理）都在这里同一个 callback 里按顺序跑。

local M = {}

-- 构造与项目里所有 LSP 客户端共享的 capabilities：
--   * blink.cmp 的补全 caps（强制 require —— 装不进来是真故障，不 pcall 吞掉）
--   * nvim-ufo 要求的 lineFoldingOnly（否则 jsonls / yamlls 等服务端不会返回 foldingRange）
-- 同时被下面的 VeryLazy `vim.lsp.config("*", ...)` 和 rustaceanvim 的
-- `server.capabilities`（在 plugins/lang/rust.lua）复用 —— 避免两份独立的
-- caps 构造逻辑。rustaceanvim 自己 `vim.lsp.start()` 启动 rust-analyzer，
-- **不**走 `vim.lsp.config("*")`，所以必须显式塞 caps 进去。
---@return lsp.ClientCapabilities
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

function M.setup()
	-- VeryLazy hook：所有"等 lazy 把基础插件装好"的 LSP 工作集中在这一个
	-- callback 里，按显式顺序跑。这取代了之前 plugins/lsp/core.lua（mason）
	-- 里独立注册的 VeryLazy autocmd —— 那种两点分注册依赖 init.lua import
	-- 顺序"恰好"先 plugins.lsp 后 core.lsp 才能 caps 在 mason 之前就位，
	-- 现在依赖关系直接由本函数体的语句顺序表达，不再隐式。
	vim.api.nvim_create_autocmd("User", {
		pattern = "VeryLazy",
		once = true,
		callback = function()
			-- 1. 全局 capabilities（VeryLazy 时 blink.cmp 已加载）
			vim.lsp.config("*", { capabilities = M.make_capabilities() })

			-- 2. Mason 自动安装缺失的 LSP server（不阻塞启动；mason 在此前由
			--    plugins/lsp/core.lua 的 eager-loaded spec 完成 require + setup）
			require("tools.mason_ensure").ensure_lsp()

			-- 3. 关掉 Neovim 0.11+ 内核自带的 gr*/gO LSP 默认键。
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

	-- 启用 LSP servers：清单从 tools/mason_ensure.lua 的 LSP_TOOLS 派生
	-- （rust_analyzer 因 external_owner = "rustaceanvim" 被自动剔除——不再两处各自维护）。
	-- ty 和 tsp_server 也在 LSP_TOOLS 内，按常规 PATH-first / mason-fallback 处理。
	local native_servers = require("tools.mason_ensure").lsp_servers_for_native_enable()
	local scheme_servers = {} -- 按工具链探测结果追加
	local toolchain = require("tools.scheme_toolchain")
	if toolchain.is_installed("racket-langserver (raco pkg)") then
		table.insert(scheme_servers, "racket_langserver")
	end
	if toolchain.is_installed("guile-lsp-server") then
		table.insert(scheme_servers, "guile_lsp_server")
	end
	if toolchain.is_installed("steel-language-server") then
		table.insert(scheme_servers, "steel_language_server")
	end

	-- 统一为所有"未自定义 root_dir"的 server 注入散文件/$HOME-safe 行为：
	-- 没 marker 命中时走 single-file（on_dir(nil)）+ cmd cwd 钉到 cache 空目录，
	-- 防 ruff/ty/lua_ls 这类服务器把 $HOME 当 fallback workspace。
	-- 自定义了 root_dir 的（denols / eslint / vtsls 的互斥逻辑）会被跳过。
	local all_servers = {}
	vim.list_extend(all_servers, native_servers)
	vim.list_extend(all_servers, scheme_servers)
	require("tools.lsp_root").apply_safe_defaults(all_servers)

	vim.lsp.enable(native_servers)
	for _, s in ipairs(scheme_servers) do
		vim.lsp.enable(s)
	end

	-- Scheme 系 LSP enable 已在上面统一处理（按 scheme_toolchain.is_installed 探测）；
	-- 后端不在时不挂，避免刷 "Client X quit with exit code 1"。FileType 触发的安装
	-- 提示走 lua/tools/scheme_toolchain.lua。装好工具后重启一次 nvim 就会启用对应
	-- LSP（同一 session 内不动态启用，因为探测结果已缓存且这个场景不值得做热重载）。

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
			map_if(
				"textDocument/codeAction",
				{ "n", "x" },
				"<leader>re",
				refactor_kind({ "refactor.extract" }),
				"Refactor: Extract …"
			)
			map_if(
				"textDocument/codeAction",
				{ "n", "x" },
				"<leader>rl",
				refactor_kind({ "refactor.inline" }),
				"Refactor: Inline"
			)
			map_if(
				"textDocument/codeAction",
				{ "n", "x" },
				"<leader>rr",
				refactor_kind({ "refactor" }),
				"Refactor: All …"
			)
			-- <leader>R 是 IdeaVim 的 RefactoringMenu，和 <leader>rr 实质同一个入口；
			-- 两个都保留以对齐 .ideavimrc（IdeaVim 那边也是双键并存）。
			map_if(
				"textDocument/codeAction",
				{ "n", "x" },
				"<leader>R",
				refactor_kind({ "refactor" }),
				"Refactor: All …"
			)
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

			-- Codelens 刷新：0.13+ 起 vim.lsp.codelens.enable 接管调度
			-- （runtime 内部走 nvim_buf_attach + debounced automatic_request，覆盖
			-- 打开 / 编辑 / 重载等修改契机），不再需要手写 BufEnter/InsertLeave/
			-- BufWritePost autocmd loop。旧 `refresh` 已 deprecated（runtime
			-- lua/vim/lsp/codelens.lua L545，目标 0.13.0）。
			if client and client:supports_method("textDocument/codeLens") then
				vim.lsp.codelens.enable(true, { bufnr = bufnr })
			end
		end,
	})

	-- Semantic token vs treesitter injection 冲突的外科修复：
	-- 默认 priority 下 `@lsp.type.string.<ft>`（125）会盖住 treesitter 注入
	-- 的内嵌语言高亮（100），让 `# language=xxx` / 类似机制注入的代码看不到
	-- 子语言着色。把这一组单独清空（无 fg/bg），其他 LSP token——deprecated
	-- 删除线、参数 vs 局部变量、类型 vs 实例等——仍按 125 正常工作。
	-- 普通字符串由 treesitter 的 `@string.<lang>` 在 100 兜底着色。
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspClearStringToken", { clear = true }),
		callback = function(args)
			local ft = vim.bo[args.buf].filetype
			if ft and ft ~= "" then
				vim.api.nvim_set_hl(0, "@lsp.type.string." .. ft, {})
			end
		end,
	})
end

return M
