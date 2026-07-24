-- 全局 LSP 配置：capabilities / enable / LspAttach keymaps
-- 所有 per-server 配置在顶层 lsp/*.lua，由 vim.lsp.enable() 自动加载。
-- 例外：rust-analyzer 由 rustaceanvim 接管（见 plugins/lang/rust.lua），不在
-- vim.lsp.enable 列表里，顶层也没有 lsp/rust_analyzer.lua。
--
-- 加载契约：本模块通过 init.lua 在 lazy.setup() **之后** require 并调
-- M.setup()。所有 LSP 相关、需等 VeryLazy 时机的工作（caps 注入 / mason 装
-- 缺失 LSP / 默认键清理）集中由 register_lsp_verylazy_hooks 注册的同一个
-- callback 按顺序跑。

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

-- pyright / basedpyright 的 textDocument/rename 结果里，TextEdit 带了
-- annotationId 却不附顶层 changeAnnotations 映射——违反 LSP 规范：
-- AnnotatedTextEdit 的 annotationId 必须能在 changeAnnotations 里查到。
-- Neovim 0.12（PR #34508）起 apply_text_edits 对此 hard assert：
--   "change_annotations must be provided for annotated text edits"
-- 于是 <leader>rn（inc-rename）和原生 vim.lsp.buf.rename 全部炸掉。上游判定
-- 为服务端 bug、不在 Neovim 侧兜（neovim/neovim#34731，status:blocked-external）。
--
-- 这里在边界把“引用了不存在 annotation 的 annotationId”抹掉，退化成普通
-- TextEdit。只动这一种违规：合规服务端（rust-analyzer 等带真 annotation +
-- needsConfirmation 的）因 changeAnnotations[id] 存在，原样放过。
---@param workspace_edit lsp.WorkspaceEdit
---@return boolean repaired 是否抹掉过至少一个孤儿 annotationId
function M.repair_unannotated_edits(workspace_edit)
	local ca = workspace_edit.changeAnnotations
	local repaired = false
	local function strip(edits)
		for _, e in ipairs(edits or {}) do
			if e.annotationId and not (ca and ca[e.annotationId]) then
				e.annotationId = nil
				repaired = true
			end
		end
	end
	-- documentChanges 既含 TextDocumentEdit（有 .edits），也含 create/rename/
	-- delete 文件操作（无 .edits）；strip 对 nil 安全，自动跳过后者。
	for _, change in ipairs(workspace_edit.documentChanges or {}) do
		strip(change.edits)
	end
	-- changes 是 uri -> TextEdit[] 的老式映射（无 documentChanges 时才有）。
	for _, edits in pairs(workspace_edit.changes or {}) do
		strip(edits)
	end
	return repaired
end

-- 关掉 Neovim 0.11+ 内核自带的 gr*/gO LSP 默认键。
-- 我们已有 gd/gi/gD + <leader>rn/<leader>ca/<leader>vs 等价物（见下方
-- setup_lsp_attach_keymaps 里的 g* / <leader>r* / <leader>ca 绑定），留着只会
-- 让 `gr`（Trouble references, 见 plugins/ui/trouble.lua）每次都要等
-- timeoutlen 消歧。
-- 注意：这些默认是 **全局** 映射（:nmap gr 输出无 `@` 标记），删除时
-- 不能传 { buffer = ... }。pcall 兜底，因为不同 nvim 版本 gr* 集合会变
-- （grx codelens 是 0.11 后期才加的）。
local function clear_default_lsp_keymaps()
	for _, lhs in ipairs({ "grn", "gra", "grr", "gri", "grt", "grx" }) do
		pcall(vim.keymap.del, "n", lhs)
	end
	pcall(vim.keymap.del, "x", "gra")
	pcall(vim.keymap.del, "n", "gO")
end

-- VeryLazy hook：LSP 相关、需等 lazy 把基础插件装好才能跑的工作（caps 注入 /
-- mason 装缺失 LSP / 清理默认键）集中在这一个 callback 里，顺序见下方数字注释。
local function register_lsp_verylazy_hooks()
	vim.api.nvim_create_autocmd("User", {
		pattern = "VeryLazy",
		once = true,
		callback = function()
			-- 1. 全局 capabilities（VeryLazy 时 blink.cmp 已加载）
			vim.lsp.config("*", { capabilities = M.make_capabilities() })

			-- 2. Mason 自动安装缺失的 LSP server（不阻塞启动；mason 在此前由
			--    plugins/lsp/core.lua 的 eager-loaded spec 完成 require + setup）
			require("tools.mason_ensure").ensure_lsp()

			-- 3. 关掉内核默认 gr*/gO 键（详见 clear_default_lsp_keymaps）
			clear_default_lsp_keymaps()
		end,
	})
end

-- Hover popup buffer 内把 K 绑为关闭 popup：
-- 默认 hover popup 没挂 LspAttach，K 会回落到 keywordprg（:help，见
-- core/options.lua），popup 里按 K 跳出一个 no-help 提示并不直觉。更符合
-- 直觉的是"再按一次 K 关掉 popup"。
local function patch_hover_close()
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

-- 修复 pyright/basedpyright 不合规的 annotated workspace edit（详见
-- M.repair_unannotated_edits 注释 / neovim/neovim#34731）。inc-rename 用自己的
-- handler 直接调 vim.lsp.util.apply_workspace_edit、绕过 vim.lsp.handlers，
-- 故只能在 util 这层 wrap——handler 覆盖盖不到它；原生 rename 也走这里。
local function patch_workspace_edit()
	local orig_apply_ws = vim.lsp.util.apply_workspace_edit
	vim.lsp.util.apply_workspace_edit = function(workspace_edit, position_encoding, ...)
		if workspace_edit and M.repair_unannotated_edits(workspace_edit) then
			vim.notify_once(
				"[lsp] 收到不合规的 annotated workspace edit（annotationId 无对应 "
					.. "changeAnnotations，多半是 pyright/basedpyright），已退化为普通 "
					.. "TextEdit；参见 neovim/neovim#34731。",
				vim.log.levels.WARN
			)
		end
		return orig_apply_ws(workspace_edit, position_encoding, ...)
	end
end

-- 启用 LSP servers：清单从 tools/mason_ensure.lua 的 LSP_TOOLS 派生（单一真相——
-- rust_analyzer 因 external_owner = "rustaceanvim" 被自动剔除）。
-- ty 和 tsp_server 也在 LSP_TOOLS 内，按常规 PATH-first / mason-fallback 处理。
local function enable_servers()
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
	-- 自定义了 root_dir 的（denols / oxlint / tsc 的互斥逻辑）会被跳过。
	-- sourcekit-lsp 随 Swift 工具链来（Xcode CLT / swiftly），不是 Mason 包，故不进
	-- LSP_TOOLS；同 Scheme 系按存在探测决定是否 enable，无 Swift 环境时不挂、不刷
	-- client-quit。此机 /usr/bin/sourcekit-lsp 直接在 PATH；executable("xcrun") 兜住
	-- 仅 full-Xcode 工具链内可达的机器（lsp/sourcekit.lua 的 cmd 会相应回落到
	-- `xcrun sourcekit-lsp`）。
	local swift_servers = {}
	if vim.fn.executable("sourcekit-lsp") == 1 or vim.fn.executable("xcrun") == 1 then
		table.insert(swift_servers, "sourcekit")
	end

	-- 原生 TS LSP（lsp/tsc.lua）：稳定通道二进制 `tsc`（typescript@7，本机由 mise 装），
	-- 预览通道 `tsgo`。都不在 Mason 稳定通道（mason 只有 tsgo 每夜版，且撞 min-release-age），
	-- 故同 Swift/Scheme 走 PATH 探测决定是否 enable，不进 LSP_TOOLS。cmd 在 tsc/tsgo 间解析。
	local ts_servers = {}
	if vim.fn.executable("tsc") == 1 or vim.fn.executable("tsgo") == 1 then
		table.insert(ts_servers, "tsc")
	end

	-- promql-langserver（lsp/promql_ls.lua）：不在 mason（Go 二进制），按
	-- tools/promql_toolchain 探测决定是否 enable——缺失时不挂、不刷 client-quit
	-- （同 scheme/swift/tsc）。只挂 promql filetype（散 .promql 文件）；yaml 规则里
	-- 的 PromQL 走注入 + pint，不靠这个 LSP。装好后重启一次 nvim 生效。
	local promql_servers = {}
	if require("tools.promql_toolchain").is_installed() then
		table.insert(promql_servers, "promql_ls")
	end

	local all_servers = {}
	vim.list_extend(all_servers, native_servers)
	vim.list_extend(all_servers, ts_servers)
	vim.list_extend(all_servers, scheme_servers)
	vim.list_extend(all_servers, swift_servers)
	vim.list_extend(all_servers, promql_servers)
	require("tools.lsp_root").apply_safe_defaults(all_servers)

	vim.lsp.enable(native_servers)
	for _, s in ipairs(scheme_servers) do
		vim.lsp.enable(s)
	end
	for _, s in ipairs(swift_servers) do
		vim.lsp.enable(s)
	end
	for _, s in ipairs(ts_servers) do
		vim.lsp.enable(s)
	end
	for _, s in ipairs(promql_servers) do
		vim.lsp.enable(s)
	end

	-- golangci_fix：进程内 codeAction server（lsp/golangci_fix.lua），把 nvim-lint
	-- 存进 diagnostic user_data 的 golangci SuggestedFixes 变成 <leader>ca /
	-- <A-CR> 可用的 quickfix。无外部二进制、无需探测；不进 apply_safe_defaults
	-- （那套 root/cwd 防御只对外部进程 server 有意义）。
	vim.lsp.enable("golangci_fix")

	-- Scheme 系 LSP enable 已在上面统一处理（按 scheme_toolchain.is_installed 探测）；
	-- 后端不在时不挂，避免刷 "Client X quit with exit code 1"。FileType 触发的安装
	-- 提示走 lua/tools/scheme_toolchain.lua。装好工具后重启一次 nvim 就会启用对应
	-- LSP（同一 session 内不动态启用，因为探测结果已缓存且这个场景不值得做热重载）。
end

-- LspAttach: 快捷键 + inlay hints
local function setup_lsp_attach_keymaps()
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

			pcall(function() vim.lsp.inlay_hint.enable(true, { bufnr = bufnr }) end)

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
			-- Refactor 命名空间。原则："LSP 能做的优先 LSP；LSP 无键级粒度时 refactoring.nvim 补"。
			--   refactoring.nvim → <leader>r{m,v,f}（treesitter，extract 三连）
			--   LSP code action  → <leader>r{e,r,s,M} + <leader>R + <leader>ca
			--   inc-rename.nvim  → <leader>rn（plugins/lsp/inc-rename.lua）
			--   智能调度       → <leader>rl LSP-first 自动 fallback 到 refactoring.nvim
			--                    inline_var（绑定见 plugins/edit/refactoring.lua）
			--
			-- LSP 标准 CodeActionKind 只有 4 层：
			-- refactor / refactor.extract / refactor.inline / refactor.rewrite。
			--
			-- 故意不绑（parity 原则：IdeaVim 有但 nvim 无对应物的键**留空**，
			-- 避免同键不同义打架肌肉记忆）：
			--   <leader>r{c,f,p,i,d,j}（IntroduceConstant / IntroduceField /
			--   IntroduceParameter / ExtractInterface / SafeDelete /
			--   ConvertPythonToJupyter）
			-- 想用 treesitter 路线的 inline / extract-to-file：
			--   `:Refactor inline_var` / `inline_func` / `extract_func_to_file`
			--
			-- <leader>rs / rM 走 LSP refactor.rewrite / refactor.move——server 支持
			-- 度参差（tsserver / ruff / rust-analyzer 较全；gopls 部分；很多语言无），
			-- 不支持时弹 "No code actions available"，是预期行为。
			local refactor_kind = function(only)
				return function() vim.lsp.buf.code_action({ context = { only = only, diagnostics = {} } }) end
			end
			-- <leader>rn 由 inc-rename.nvim 处理（plugins/lsp/inc-rename.lua）
			map_if(
				"textDocument/codeAction",
				{ "n", "x" },
				"<leader>re",
				refactor_kind({ "refactor.extract" }),
				"Refactor: Extract …"
			)
			-- <leader>rl 由 plugins/edit/refactoring.lua 接管为 LSP-first + treesitter
			-- 自动 fallback 调度器；这里不再绑（buffer-local 会盖全局）。
			map_if(
				"textDocument/codeAction",
				{ "n", "x" },
				"<leader>rs",
				refactor_kind({ "refactor.rewrite" }),
				"Refactor: Rewrite / change signature"
			)
			map_if(
				"textDocument/codeAction",
				{ "n", "x" },
				"<leader>rM",
				refactor_kind({ "refactor.move" }),
				"Refactor: Move to file"
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
			-- <A-CR>:同一入口，对齐 JetBrains 原生 Alt-Enter（ShowIntentionActions，
			-- IDE 侧无需 IdeaVim 映射，见 .ideavimrc §Refactoring）。终端链路依赖
			-- Opt 被当作 Alt 发送——Ghostty `macos-option-as-alt = left` → 仅左 Opt；
			-- tmux 传统 ESC+CR 编码即可，不需要 extended-keys。
			map("n", "<A-CR>", vim.lsp.buf.code_action, "Code Action (IDE Alt-Enter)")
			-- Codelens：运行光标行的 lens（gopls test runner / rustaceanvim Run|Debug /
			-- tsc references/implementations / clangd parameters 等）。对应上游默认键里已禁用的
			-- `grx`（见 clear_default_lsp_keymaps）。
			-- IdeaVim 侧无对应键——JetBrains 的 lens 走 gutter 图标 + IDE Run/Debug 快捷键
			-- (Shift+F10 等)，不通过 IdeaVim mapping。这是 CLAUDE.md 允许的"genuinely
			-- nvim-only"非对称项。
			map_if("textDocument/codeLens", "n", "<leader>cl", vim.lsp.codelens.run, "Run Code Lens")
			-- <leader>n* — extras that have no standard g* counterpart:
			map_if(
				"textDocument/prepareTypeHierarchy",
				"n",
				"<leader>nb",
				function() vim.lsp.buf.typehierarchy("supertypes") end,
				"Goto Base (supertypes)"
			)

			-- Codelens 刷新：0.13+ 起 vim.lsp.codelens.enable 接管调度（runtime 内部
			-- 走 nvim_buf_attach + debounced automatic_request，覆盖打开 / 编辑 /
			-- 重载等修改契机）。`refresh` 已 deprecated（runtime
			-- lua/vim/lsp/codelens.lua L545，目标 0.13.0）。
			if client and client:supports_method("textDocument/codeLens") then
				vim.lsp.codelens.enable(true, { bufnr = bufnr })
			end
		end,
	})
end

-- Semantic token vs treesitter injection 冲突的外科修复：
-- 默认 priority 下 `@lsp.type.string.<ft>`（125）会盖住 treesitter 注入
-- 的内嵌语言高亮（100），让 `# language=xxx` / 类似机制注入的代码看不到
-- 子语言着色。把这一组单独清空（无 fg/bg），其他 LSP token——deprecated
-- 删除线、参数 vs 局部变量、类型 vs 实例等——仍按 125 正常工作。
-- 普通字符串由 treesitter 的 `@string.<lang>` 在 100 兜底着色。
local function fix_semantic_string_tokens()
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

-- 打开 promql buffer 时,若 promql-langserver 缺失则 notify 安装命令(同 scheme 的
-- scheme_toolchain 提示)。注册在 core/lsp 而非某 plugin init——promql 无 plugin 层
-- (parser 集中在 treesitter.lua,LSP 在 core),FileType 通知自然归这里。
local function register_promql_toolchain_notify()
	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("UserPromqlToolchain", { clear = true }),
		pattern = "promql",
		callback = function() require("tools.promql_toolchain").check_for_ft("promql") end,
	})
end

-- promql-langserver 运行时改后端 URL（LSP didChangeConfiguration 热配置，无需重启）。
-- server 端 langserver/config.go 期望 params.settings = { promql = { url = ... } }
-- （json key promql.url）。这是 env `LANGSERVER_PROMETHEUSURL`（声明式/持久，见
-- lsp/promql_ls.lua 头注释）的命令式补充：session 内即时生效，且记住 URL——之后新
-- attach 的 promql_ls client 自动补推（设一次，全 session 的 .promql 都连上）。
local promql_runtime_url = nil

---@param client vim.lsp.Client
---@param url string
local function promql_push_url(client, url)
	client:notify("workspace/didChangeConfiguration", { settings = { promql = { url = url } } })
end

local function register_promql_commands()
	vim.api.nvim_create_user_command("PromqlUrl", function(opts)
		local url = vim.trim(opts.args)
		if url == "" then
			-- 无参：回显当前已设的 URL（server 不暴露"读"，只能回显我们记住的）。
			vim.notify(
				promql_runtime_url and ("[promql] current backend: " .. promql_runtime_url)
					or "[promql] usage: :PromqlUrl http://host:9090   (no backend set — offline)",
				vim.log.levels.INFO
			)
			return
		end
		promql_runtime_url = url
		local clients = vim.lsp.get_clients({ name = "promql_ls" })
		if #clients == 0 then
			vim.notify(
				"[promql] URL saved but no promql-langserver client attached yet — open a .promql "
					.. "buffer (and install the server); it will be applied on attach.",
				vim.log.levels.WARN
			)
			return
		end
		for _, c in ipairs(clients) do
			promql_push_url(c, url)
		end
		vim.notify(
			("[promql] backend set to %s (%d client%s) — watch for the server's connect result."):format(
				url,
				#clients,
				#clients == 1 and "" or "s"
			),
			vim.log.levels.INFO
		)
	end, { nargs = "?", desc = "Set promql-langserver Prometheus backend URL (runtime, hot-reload)" })

	-- 新 attach 的 promql_ls 补推已记住的 URL（session-sticky，不必每文件重跑）。
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserPromqlUrlReapply", { clear = true }),
		callback = function(args)
			if not promql_runtime_url then
				return
			end
			local c = vim.lsp.get_client_by_id(args.data.client_id)
			if c and c.name == "promql_ls" then
				promql_push_url(c, promql_runtime_url)
			end
		end,
	})
end

function M.setup()
	register_lsp_verylazy_hooks()
	patch_hover_close()
	patch_workspace_edit()
	enable_servers()
	setup_lsp_attach_keymaps()
	fix_semantic_string_tokens()
	register_promql_toolchain_notify()
	register_promql_commands()
end

return M
