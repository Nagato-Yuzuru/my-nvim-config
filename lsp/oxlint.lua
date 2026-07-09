-- oxlint: oxc linter，通过 `oxlint --lsp` 直接当 LSP（诊断 + oxc.fixAll code action），
-- 取代 eslint-lsp。fixAll 是工作区命令 oxc.fixAll，绑在 <leader>ff（见 conform.lua）。
-- 与 denols 互斥：Deno 项目跳过（deno lint 内置）。
--
-- 类型感知 lint 自动开：PATH（或项目 node_modules/.bin）上有 tsgolint 且 .oxlintrc.json
-- 含 "typescript" 时，before_init 注入 typeAware=true。tsgolint 复用你已装的 tsgo 类型
-- 检查器，但**无 mason 包**——需手动装（untracked，故不进 mason_ensure）；没装就静默按
-- AST-only 规则跑，此处的自动探测让它一旦上 PATH 就即时生效、无需改配置。
local DENO_MARKERS = { "deno.json", "deno.jsonc", "deno.lock" }
local OXLINT_MARKERS = { ".oxlintrc.json", ".oxlintrc.jsonc", "oxlint.config.ts", "package.json" }

local function conf_mentions_typescript(root_dir)
	for _, name in ipairs({ ".oxlintrc.json", ".oxlintrc.jsonc" }) do
		local fn = vim.fs.joinpath(root_dir, name)
		if vim.fn.filereadable(fn) == 1 then
			for line in io.lines(fn) do
				if line:find("typescript", 1, true) then
					return true
				end
			end
		end
	end
	return false
end

local function has_tsgolint(root_dir)
	if vim.fn.executable("tsgolint") == 1 then
		return true
	end
	return root_dir ~= nil and vim.fn.executable(vim.fs.joinpath(root_dir, "node_modules/.bin", "tsgolint")) == 1
end

return {
	cmd = function(dispatchers, config)
		local cmd = "oxlint"
		if (config or {}).root_dir then
			local local_cmd = vim.fs.joinpath(config.root_dir, "node_modules/.bin", cmd)
			if vim.fn.executable(local_cmd) == 1 then
				cmd = local_cmd
			end
		end
		return vim.lsp.rpc.start({ cmd, "--lsp" }, dispatchers)
	end,
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	root_markers = OXLINT_MARKERS,
	root_dir = function(bufnr, on_dir)
		if vim.fs.root(bufnr, DENO_MARKERS) then
			return
		end
		local root = vim.fs.root(bufnr, OXLINT_MARKERS)
		if root then
			on_dir(root)
		end
	end,
	before_init = function(init_params, config)
		if config.root_dir and has_tsgolint(config.root_dir) then
			local ok, mentions = pcall(conf_mentions_typescript, config.root_dir)
			if ok and mentions then
				local init_options = config.init_options or {}
				init_options.settings = vim.tbl_extend("force", init_options.settings or {}, { typeAware = true })
				config.init_options = init_options
				init_params.initializationOptions = init_options
			end
		end
	end,
}
