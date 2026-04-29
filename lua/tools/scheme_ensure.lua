-- Scheme 工具链非 Mason 安装探测
--
-- mason-registry 里没有 racket-langserver / guile-lsp-server / steel-language-server
-- / schemat / raco fmt，所以走不了 tools/mason_ensure.lua 那条路。
-- 这里只做 "缺什么 → 一次性 notify 准确的安装命令"，不自动 cargo install /
-- raco pkg install——那些写到全局工具链的动作不该在 nvim 启动时偷偷跑。
--
-- 触发：plugins/lang/scheme.lua 里的 FileType 自动命令调一次 check_for_ft(ft)。
-- 同一 filetype 一次 session 只 notify 一次。CI / NO_AUTO_INSTALL 时短路。
--
-- 探测分两类：
--   1. PATH 二进制（guile / steel / schemat 等）→ vim.fn.executable
--   2. Racket 包（racket-langserver / fmt）→ raco pkg show，因为 raco pkg install
--      装的是 Racket 库而不是 PATH 二进制。Racket LSP 的 cmd 是
--      `racket --lib racket-langserver`，靠 raco 找到包，executable 永远 0。
-- 探测结果会缓存（避免每次 LSP 启动判定都 fork raco 子进程）。

local M = {}

local function has_exec(bin)
	return vim.fn.executable(bin) == 1
end

local racket_pkg_cache = {}

-- 探测 Racket 包是否安装。`raco pkg show <pkg>` 总是 exit 0（不论包在不在），
-- 所以必须解析 stdout。输出形如：
--
--   Installation-wide:
--    Package[*=auto]   Checksum   Source           ← header
--    base*             a7c0b66... catalog base     ← installed row
--   User-specific for installation "X":
--    [none]                                         ← nothing at this scope
--
-- 检测：扫每一缩进行，取第一列（剥掉 `*` 自动安装标记）。匹配 pkg 名 = 安装。
-- `[none]` 行第一列就是 `[none]`，不会撞包名。表头 `Package[*=auto]` 同理。
local function has_racket_pkg(pkg)
	if racket_pkg_cache[pkg] ~= nil then
		return racket_pkg_cache[pkg]
	end
	if not has_exec("raco") then
		racket_pkg_cache[pkg] = false
		return false
	end
	local out = vim.fn.system({ "raco", "pkg", "show", pkg })
	local installed = false
	for line in out:gmatch("[^\n]+") do
		-- 第一列必须有缩进（数据行）+ 后面跟着列分隔的空格（区分 `[none]` 这种孤行）
		local first = line:match("^%s+(%S+)%s+")
		if first then
			first = first:gsub("%*$", "") -- 剥 auto-install 标记
			if first == pkg then
				installed = true
				break
			end
		end
	end
	racket_pkg_cache[pkg] = installed
	return installed
end

-- 工具描述：display name → { check fn, install hint }。
-- check 返回 true 时认为已安装。
local TOOLS = {
	racket = {
		check = function()
			return has_exec("racket")
		end,
		hint = "brew install minimal-racket",
	},
	raco = {
		check = function()
			return has_exec("raco")
		end,
		hint = "brew install minimal-racket   # raco ships with racket itself",
	},
	["racket-langserver (raco pkg)"] = {
		check = function()
			return has_racket_pkg("racket-langserver")
		end,
		hint = "raco pkg install racket-langserver   # Racket library, not a PATH binary",
	},
	["fmt (raco pkg)"] = {
		check = function()
			return has_racket_pkg("fmt")
		end,
		hint = "raco pkg install fmt   # provides `raco fmt` Racket formatter",
	},
	guile = {
		check = function()
			return has_exec("guile")
		end,
		hint = "brew install guile",
	},
	["guile-lsp-server"] = {
		check = function()
			return has_exec("guile-lsp-server")
		end,
		hint = "build from source: https://codeberg.org/rgherdt/scheme-lsp-server   # or: guix install guile-lsp-server",
	},
	steel = {
		check = function()
			return has_exec("steel")
		end,
		hint = "cargo install --git https://github.com/mattwparas/steel steel",
	},
	["steel-language-server"] = {
		check = function()
			return has_exec("steel-language-server")
		end,
		hint = "cargo install --git https://github.com/mattwparas/steel steel-language-server",
	},
	schemat = {
		check = function()
			return has_exec("schemat")
		end,
		hint = "cargo install schemat   # or git: https://github.com/raymond-w-ko/schemat",
	},
}

-- 每个 filetype 关心哪些工具（不是所有 .scm 都需要 Steel 工具链；racket 这边
-- 也不需要碰 Guile。scheme buffer 取保守的并集，因为没有更精确的项目分辨方法）
local TOOLS_BY_FT = {
	racket = { "racket", "raco", "racket-langserver (raco pkg)", "fmt (raco pkg)" },
	scheme = { "guile", "guile-lsp-server", "steel", "steel-language-server", "schemat" },
}

-- 暴露给 core/lsp.lua 用：在 vim.lsp.enable 之前判断 LSP 后端是否可用，
-- 避免 racket_langserver / steel_language_server 启动失败刷屏。
function M.is_installed(name)
	local t = TOOLS[name]
	if not t then
		return false
	end
	return t.check()
end

local notified = {}

function M.check_for_ft(ft)
	if vim.env.CI == "true" or vim.env.NO_AUTO_INSTALL == "1" then
		return
	end
	if notified[ft] then
		return
	end
	notified[ft] = true

	local needed = TOOLS_BY_FT[ft]
	if not needed then
		return
	end

	local missing = {}
	for _, name in ipairs(needed) do
		local t = TOOLS[name]
		if t and not t.check() then
			table.insert(missing, ("  • %-32s →   %s"):format(name, t.hint))
		end
	end

	if #missing == 0 then
		return
	end

	vim.notify(
		("[scheme] Missing tools for %s buffers — install manually:\n%s"):format(
			ft, table.concat(missing, "\n")
		),
		vim.log.levels.WARN
	)
end

return M
