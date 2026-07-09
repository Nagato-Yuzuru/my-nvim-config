-- tsc: TypeScript 7 原生（Go 口）语言服务器，接管 Node 侧 JS/TS。
-- GA 后稳定通道的二进制叫 `tsc`（typescript@7 包，本机由 mise 装 npm-typescript）；
-- 预览通道叫 `tsgo`（@typescript/native-preview 包）。同一份原生实现、不同通道命名，
-- LSP 都走 `<bin> --lsp --stdio`。
--   * cmd 按「项目本地 tsc → 本地 tsgo → 全局 tsc → 全局 tsgo」解析：项目自钉版本
--     优先（可复现），否则回落 PATH 上的全局（mise 的 tsc）。
--   * 无 Mason 稳定包（mason 的 tsgo 只有 native-preview 每夜版，且撞 ~/.npmrc 的
--     min-release-age），故**不进 LSP_TOOLS**——改由 core/lsp.lua 按
--     `executable(tsc|tsgo)` 探测决定是否 enable（同 Swift / Scheme 系）。
--   * 与 denols 互斥：buffer 落在 Deno 程序内时让位（按最近 package-manager lockfile
--     vs deno.json/deno.lock 深度比较，正确处理 Node monorepo 里嵌 Deno 包）。原生支持
--     monorepo，单实例按 buffer 自动找对应 tsconfig。
--   * 自带 root_dir + 函数式 cmd，列进 lsp_root.lua 的 SKIP，中央 force-replace 不覆盖。
-- inlayHints 走标准 typescript.*/javascript.* 键；updateImportsOnFileMove /
-- completeFunctionCalls 是标准 tsserver 设置，原生口是否全吃未逐一核实，不吃则静默忽略。
local INLAY_HINTS = {
	parameterNames = { enabled = "literals", suppressWhenArgumentMatchesName = true },
	parameterTypes = { enabled = true },
	variableTypes = { enabled = false },
	propertyDeclarationTypes = { enabled = true },
	functionLikeReturnTypes = { enabled = true },
	enumMemberValues = { enabled = true },
}

-- 解析原生 TS 二进制：项目本地优先（tsc 稳定 / tsgo 预览），再回落全局。
local function resolve_bin(root_dir)
	local names = { "tsc", "tsgo" }
	if root_dir then
		for _, name in ipairs(names) do
			local p = vim.fs.joinpath(root_dir, "node_modules/.bin", name)
			if vim.fn.executable(p) == 1 then
				return p
			end
		end
	end
	for _, name in ipairs(names) do
		if vim.fn.executable(name) == 1 then
			return name
		end
	end
	return "tsc"
end

---@type vim.lsp.Config
return {
	cmd = function(dispatchers, config)
		return vim.lsp.rpc.start({ resolve_bin((config or {}).root_dir), "--lsp", "--stdio" }, dispatchers)
	end,
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	root_dir = function(bufnr, on_dir)
		-- 项目根 = 最近的 package-manager lockfile（原生口从这里就能覆盖 monorepo 与
		-- 单包工程）；0.11.3+ 用嵌套表让 lockfile 与 .git 同级优先。
		local root_markers = { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" }
		root_markers = vim.fn.has("nvim-0.11.3") == 1 and { root_markers, { ".git" } }
			or vim.list_extend(root_markers, { ".git" })

		local deno_root = vim.fs.root(bufnr, { "deno.json", "deno.jsonc" })
		local deno_lock_root = vim.fs.root(bufnr, { "deno.lock" })
		local project_root = vim.fs.root(bufnr, root_markers)
		-- deno.lock 比 package lockfile 更近 → Deno 文件，让位给 denols
		if deno_lock_root and (not project_root or #deno_lock_root > #project_root) then
			return
		end
		-- deno.json 与 package lockfile 同级或更近 → Deno 文件，让位给 denols
		if deno_root and (not project_root or #deno_root >= #project_root) then
			return
		end
		on_dir(project_root or vim.fn.getcwd())
	end,
	settings = {
		typescript = {
			inlayHints = INLAY_HINTS,
			updateImportsOnFileMove = { enabled = "always" },
			suggest = { completeFunctionCalls = true },
		},
		javascript = {
			inlayHints = INLAY_HINTS,
			updateImportsOnFileMove = { enabled = "always" },
		},
	},
}
