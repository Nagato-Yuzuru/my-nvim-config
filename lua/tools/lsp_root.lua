-- LSP root resolution with $HOME-aware single-file fallback.
--
-- 契约（单一所有权）：本模块是所有**非 SKIP** server 的 root_dir 唯一所有者。
-- lsp/<name>.lua 里不要再手写 root_dir——apply_safe_defaults 会用各文件声明的
-- root_markers 统一生成 root_dir，并经 vim.lsp.config(name, {...}) 注入。而
-- vim.lsp.config 对 root_dir 这种非 table 字段是 force-replace（内部
-- tbl_deep_extend "force"，后写整体覆盖先写），所以 apply_safe_defaults 之后
-- 文件里那份 root_dir 一律成死代码、永不执行——且**静默**失效（没有报错）。
-- 要自定义 root_dir 的 server 必须显式加入 SKIP，否则它的 root_dir 被无声吞掉。
--
-- 背景：从 nvim-lspconfig 迁到 Neovim 0.12 native LSP 后，原本由 lspconfig 的
-- `single_file_support = true` + `root_pattern(...)` 提供的兜底没了——手写的
-- `root_dir` fallback 到 `vim.fs.dirname(bufname)`，导致 `~/foo.py` 这种散文件
-- 把 $HOME 当 workspace，ty/ruff 直接全扫家目录树。
--
-- 这里的 resolve 区分三种结果：
--   * string : 真正的项目 root（有 marker，或散文件但目录"够小"）
--   * false  : 单文件模式——caller 应 `on_dir(nil)`，让 client 不带
--              workspaceFolders 启动（LSP 标准的 single-file 语义；
--              见 runtime/lua/vim/lsp.lua:741 workspace_required 分支）
--   * nil    : 跳过启动（buffer 没文件名）
local M = {}

---@param bufnr integer
---@param markers string[]
---@param unnamed_cwd? boolean 无名 buffer 是否落到 cwd（仅 ty 用，见 UNNAMED_CWD）
---@return string|false|nil
function M.resolve(bufnr, markers, unnamed_cwd)
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	-- Conjure 的 REPL log buffer（conjure-log-*.rkt / *.scm）带真实 filetype，
	-- 会触发 enable 的 FileType attach；但它不是磁盘文件，root 会顺着 cwd 的
	-- .git 解析到无关仓库，给同一 server 挂出第二个 client（root 不同不去重）。
	-- 一律不为其启动 LSP。
	if bufname:find("conjure%-log%-") then
		return nil
	end
	local dir
	if bufname == "" then
		-- 默认无名 buffer 跳过（没路径无从定位 root）。ty 例外：scratch python
		-- buffer 也要类型检查，落到 cwd 当 root——但仍走下面同一套 $HOME 兜底，
		-- 绝不把 $HOME 注册成 workspace（cwd 是 $HOME/祖先/根时退化为单文件模式）。
		if not unnamed_cwd then
			return nil
		end
		dir = vim.uv.cwd()
	else
		local root = vim.fs.root(bufnr, markers)
		if root then
			return root
		end
		dir = vim.fs.dirname(bufname)
	end

	local home = vim.uv.os_homedir()
	-- dir 是 $HOME 本身、$HOME 的祖先、或文件系统根 → 单文件模式
	if dir == home or (home and vim.startswith(home, dir .. "/")) or dir == "/" then
		return false
	end
	return dir
end

-- 便利 wrapper：直接生成符合 vim.lsp.config 的 root_dir 函数。
---@param markers string[]
---@param unnamed_cwd? boolean 透传给 M.resolve（ty 的无名 buffer → cwd 语义）
---@return fun(bufnr: integer, on_dir: fun(root?: string))
function M.root_dir(markers, unnamed_cwd)
	return function(bufnr, on_dir)
		local r = M.resolve(bufnr, markers, unnamed_cwd)
		if r == nil then
			return
		end
		if r == false then
			on_dir(nil) -- single-file mode (no workspaceFolders)
		else
			on_dir(r)
		end
	end
end

-- 返回一个 single-file-mode 友好的 cmd 包装：当 client 没拿到 root_dir 时（即
-- 单文件模式），用一个空 cache 目录当 server 进程 cwd，截断 ruff/ty/lua_ls 这
-- 类服务器的"无 workspace 就 fallback 到 cwd"行为——否则从 $HOME 起 nvim 时，
-- 它们的 cwd 仍是 $HOME，又会去 Registering workspace: /Users/colas 爬整棵树。
--
-- 项目模式下 cwd 留给 LSP 框架默认（不显式设 → 进程继承 nvim cwd），保持
-- 与既往行为一致。
---@param cmd string[]
---@return fun(dispatchers: table, config: table): table
function M.cmd_with_safe_cwd(cmd)
	local cache_root = vim.fn.stdpath("cache") .. "/lsp-single-file"
	return function(dispatchers, config)
		local cwd
		if not config.root_dir then
			vim.fn.mkdir(cache_root, "p")
			cwd = cache_root
		end
		return vim.lsp.rpc.start(cmd, dispatchers, { cwd = cwd })
	end
end

-- 唯一允许在 lsp/<name>.lua 里自带 root_dir 的 server（互斥 / 多 marker 逻辑
-- 本 helper 表达不了）。中央层对这些放手不覆盖：
--   * denols / vtsls: deno vs node 互斥（谁的 marker 更深谁赢）
--   * eslint: buffer 落在 deno 项目内时让位给 denols
local SKIP = { denols = true, eslint = true, vtsls = true }

-- 无名 buffer 也想要 LSP 的 server：默认散文件无路径直接跳过，这些 server 例外，
-- 无名时落到 cwd 当 root（仍受 resolve 的 $HOME 兜底约束）。
--   * ty: scratch python buffer 也做类型检查
local UNNAMED_CWD = { ty = true }

-- 批量为 server 列表注入安全 root 行为：
--   * 在 SKIP 名单里 → 跳过（让位给 lsp/<name>.lua 的自定义 root_dir）
--   * 否则用 lsp/<name>.lua 里声明的 root_markers 强制生成 root_dir，覆盖
--     文件里可能存在的"fallback 到 file dirname"那种会爬 $HOME 的写法；
--     cmd 也包成 cmd_with_safe_cwd 截断 server 自己的 cwd-fallback。
-- 调用时机：在 vim.lsp.enable() 之前，所有 lsp/*.lua 已被 framework 解析过。
--
-- 设计取舍：强制覆盖（force-replace）比"只在 root_dir 缺失时注入"更鲁棒——
-- 避免 lsp/*.lua 里复制粘贴的 fallback 兜底重新引入扫 $HOME 的 bug。代价是
-- 副作用是静默的：非 SKIP server 若在文件里手写 root_dir，会被无声吞掉、不
-- 报错。这份 SKIP 名单正是本模块单一所有权契约的执行点，唯一的补救是把该
-- server 显式列进 SKIP。
---@param names string[]
function M.apply_safe_defaults(names)
	for _, name in ipairs(names) do
		if not SKIP[name] then
			local cfg = vim.lsp.config[name]
			if cfg and cfg.root_markers then
				local patch = { root_dir = M.root_dir(cfg.root_markers, UNNAMED_CWD[name]) }
				if type(cfg.cmd) == "table" then
					patch.cmd = M.cmd_with_safe_cwd(cfg.cmd)
				end
				vim.lsp.config(name, patch)
			end
		end
	end
end

return M
