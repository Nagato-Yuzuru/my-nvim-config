-- tsc: TypeScript 7 原生（Go 口）语言服务器，接管 Node 侧 JS/TS，`tsc --lsp --stdio`。
--   * 二进制由 mason_ensure 的 LSP_TOOLS 管：PATH 上的 tsc（mise 的 npm-typescript）优先，
--     mason 的 `tsc`（typescript@7）兜底。
--   * 不用项目本地 node_modules/.bin/tsc：TS 5/6 的 tsc 没有 --lsp，起不来。TS 5 项目照样
--     由 TS 7 服务——tsconfig 里 TS 7 已移除的选项（baseUrl / moduleResolution node10 /
--     target es5 …）会报配置诊断，以项目自己的 tsc 构建为准。
--   * 与 denols 互斥：buffer 落在 Deno 程序内时让位（按最近 package-manager lockfile
--     vs deno.json/deno.lock 深度比较，正确处理 Node monorepo 里嵌 Deno 包）。原生支持
--     monorepo，单实例按 buffer 自动找对应 tsconfig。
--   * 自带 root_dir，列进 lsp_root.lua 的 SKIP，中央 force-replace 不覆盖。
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

---@type vim.lsp.Config
return {
	cmd = { "tsc", "--lsp", "--stdio" },
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
