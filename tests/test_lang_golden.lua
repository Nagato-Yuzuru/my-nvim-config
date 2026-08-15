-- 迁移期 golden 对照（**随迁移波尾删除，不长期保留**——否则每加一门语言都要来
-- 改这份快照，沦为 change-detector）。断言语言域注册的聚合结果与迁移前
-- core/lsp.lua 手写分支 + core/options.lua ft 表逐项相等，钉住抄写错误。
-- child 里 require 各语言域模块：minimal harness 无 lazy，顶层 register 照跑。

local H = require("tests.helpers")
local child, hooks = H.new_child()
local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

local LANG_MODULES = {
	"plugins.lang.docker",
	"plugins.lang.go",
	"plugins.lang.markdown",
	"plugins.lang.opentofu",
	"plugins.lang.promql",
	"plugins.lang.scheme",
	"plugins.lang.swift",
	"plugins.lang.typescript",
}

local function load_langs()
	child.lua(
		[[
		for _, m in ipairs(...) do
			require(m)
		end
	]],
		{ LANG_MODULES }
	)
end

T["server inventory matches the pre-migration hand-written branches"] = function()
	load_langs()
	local servers = child.lua_get([[
		(function()
			local out = {}
			for lang, spec in pairs(require("tools.lang_registry").declared()) do
				for server, entry in pairs(spec.lsp or {}) do
					out[server] = {
						lang = lang,
						probe = type(entry.probe),
						in_process = entry.in_process or false,
					}
				end
			end
			return out
		end)()
	]])
	eq(servers, {
		racket_langserver = { lang = "scheme", probe = "function", in_process = false },
		guile_lsp_server = { lang = "scheme", probe = "function", in_process = false },
		steel_language_server = { lang = "scheme", probe = "function", in_process = false },
		sourcekit = { lang = "swift", probe = "table", in_process = false },
		tsc = { lang = "typescript", probe = "table", in_process = false },
		promql_ls = { lang = "promql", probe = "function", in_process = false },
		golangci_fix = { lang = "go", probe = "nil", in_process = true },
	})
end

T["ft aggregate matches the pre-migration core/options.lua table"] = function()
	load_langs()
	local merged = child.lua_get([[
		(function()
			local out = {}
			for _, spec in pairs(require("tools.lang_registry").declared()) do
				for kind, entries in pairs(spec.ft or {}) do
					out[kind] = out[kind] or {}
					for k, v in pairs(entries) do
						out[kind][k] = v
					end
				end
			end
			return out
		end)()
	]])
	eq(merged, {
		pattern = {
			["docker%-compose%.ya?ml"] = "yaml.docker-compose",
			["%.?[Dd]ockerfile%..+"] = "dockerfile",
		},
		extension = {
			tfvars = "terraform-vars",
			tofu = "terraform",
			tofuvars = "terraform-vars",
			gotmpl = "gotmpl",
			mdx = "markdown.mdx",
			promql = "promql",
		},
		filename = {
			["go.work"] = "gowork",
		},
	})
end

T["apply_ft end-to-end: vim.filetype.match resolves like before"] = function()
	load_langs()
	child.lua([[require("tools.lang_registry").apply_ft()]])
	local cases = {
		{ "a.tofu", "terraform" },
		{ "a.tfvars", "terraform-vars" },
		{ "go.work", "gowork" },
		{ "docker-compose.yml", "yaml.docker-compose" },
		-- 注：nvim 的 ft pattern 为全锚定匹配，"app.Dockerfile.dev" 在旧配置下同样
		-- 不命中（已用 --clean + 旧表实测）；"Dockerfile.dev" 才是该 pattern 的真实形态。
		{ "Dockerfile.dev", "dockerfile" },
		{ "q.promql", "promql" },
		{ "doc.mdx", "markdown.mdx" },
		{ "tpl.gotmpl", "gotmpl" },
	}
	for _, c in ipairs(cases) do
		eq(child.lua_get(([[vim.filetype.match({ filename = %q })]]):format(c[1])), c[2])
	end
end

return T
