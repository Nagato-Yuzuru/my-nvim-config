-- 回归/缺陷测试:每个用例复现 image-remote-trust 代码审查(xhigh)确认的一个
-- bug,断言的是**期望行为**,故当前应全部 RED——把它们改绿是另一个 agent 的
-- GREEN 相(见 docs/rfcs/image-remote-trust-handoff.md)。用例名前缀 #N 对应
-- 交接文档里的 finding 编号。审查里另有几条无法在 child 单元层复现(buf.attach
-- 绕过、reveal 异步卡死、sentinel 伪造、热路径 syscall 等),那些只在交接文档
-- 里描述,不在本文件。

local H = require("tests.helpers")
local child, hooks = H.new_child()

local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

local IR = "require('tools.image_render')"
local URL = "https://example.com/a.png"

-- child 里建隔离环境:独立 state/cache dir(不碰真实 stdpath),可选建若干
-- 「git 仓库」(.git + doc.md)。返回 { base, repos = { name = {root, doc} } }。
local function isolate(spec)
	return child.lua_get(
		[[(function(spec)
			local uv = vim.uv
			local base = vim.fn.tempname()
			vim.fn.mkdir(base, "p")
			base = uv.fs_realpath(base)
			vim.env.XDG_STATE_HOME = base .. "/state"
			vim.env.XDG_CACHE_HOME = base .. "/cache"
			local out = { base = base, repos = vim.empty_dict() }
			for _, name in ipairs(spec.repos or {}) do
				local repo = base .. "/" .. name
				vim.fn.mkdir(repo .. "/.git", "p")
				local doc = repo .. "/doc.md"
				vim.fn.writefile({ "x" }, doc)
				out.repos[name] = { root = uv.fs_realpath(repo), doc = doc }
			end
			return out
		end)(...)]],
		{ spec or {} }
	)
end

-- ============================================================ #11 FILE:// 大小写
-- URI scheme 大小写不敏感(RFC 3986)且模块注释承诺「放行本地 file://」,
-- 但 scheme ~= "file" 大小写敏感 → 大写 FILE:// 被误判为远程并拦掉。
T["#11 is_remote_src treats uppercase FILE:// as local"] = function()
	eq(child.lua_get(IR .. ".is_remote_src('FILE:///Users/me/x.png')"), false)
end

-- ============================================================ #6 repo_root 负缓存
-- repo_root 把「非 git 目录」永久负缓存,git init 后 ,iar 仍拒绝。
T["#6 trust_repo succeeds after git init mid-session"] = function()
	local env = isolate({})
	child.lua(
		("vim.fn.mkdir(%q, 'p'); vim.fn.writefile({'x'}, %q)"):format(env.base .. "/proj", env.base .. "/proj/doc.md")
	)
	local doc = env.base .. "/proj/doc.md"
	-- 渲染路径先摸一次 → 该目录被负缓存为「非 git」
	child.lua((IR .. ".is_trusted(%q, %q)"):format(doc, URL))
	-- 用户随后 git init
	child.lua(("vim.fn.mkdir(%q, 'p')"):format(env.base .. "/proj/.git"))
	-- 期望:现在能授予
	eq(child.lua_get(("type(" .. IR .. ".trust_repo(%q))"):format(doc)), "string")
end

-- ============================================================ #9 norm_path key 漂移
-- 未落盘时 realpath 失败 → 存 normalize 回退 key;:w 后 realpath 解掉符号链接
-- → key 变、授予静默失效。
T["#9 file grant survives :w through a symlinked dir"] = function()
	local env = isolate({})
	child.lua(
		([[vim.fn.mkdir(%q, "p"); vim.uv.fs_symlink(%q, %q)]]):format(
			env.base .. "/real",
			env.base .. "/real",
			env.base .. "/link"
		)
	)
	local doc = env.base .. "/link/new.md"
	-- 文件尚不存在 → ,iaf 授予(存 normalize 回退 key)
	child.lua((IR .. ".trust_file(%q)"):format(doc))
	-- 用户 :w 落盘
	child.lua(("vim.fn.writefile({'x'}, %q)"):format(doc))
	-- 期望:同一逻辑文件仍被信任
	eq(child.lua_get((IR .. ".is_trusted(%q, %q)"):format(doc, URL)), true)
end

-- ============================================================ #2 $HOME 过度授予
-- ~/.git 存在(dotfiles-as-repo)时,vim.fs.root 返回 $HOME,,iar 会把整个家
-- 目录持久信任;需拒绝过宽 root。
T["#2 trust_repo rejects a git root equal to $HOME"] = function()
	local env = isolate({})
	local home = child.lua_get(
		[[(function(base)
			local uv = vim.uv
			local home = base .. "/home"
			vim.fn.mkdir(home .. "/.git", "p")
			vim.fn.writefile({ "x" }, home .. "/notes.md")
			home = uv.fs_realpath(home)
			vim.env.HOME = home
			return home
		end)(...)]],
		{ env.base }
	)
	-- 期望:拒绝($HOME 作为 root 太宽)
	eq(child.lua_get(("type(" .. IR .. ".trust_repo(%q))"):format(home .. "/notes.md")), "nil")
end

-- ============================================================ #3 多实例互相覆盖
-- 持久库一进程只读一次、save 写内存快照,无重读/合并/锁 → 另一实例并发授予
-- 被静默抹掉。
T["#3 concurrent instance's grant is not clobbered on save"] = function()
	local env = isolate({ repos = { "A", "C" } })
	child.lua((IR .. ".trust_repo(%q)"):format(env.repos.A.doc))
	-- 「另一个 nvim 实例」独立把 B 写进同一持久库文件
	child.lua(([[
		local dir = vim.env.XDG_STATE_HOME .. "/nvim"
		vim.fn.mkdir(dir, "p")
		local f = assert(io.open(dir .. "/image-remote-trust.json", "w"))
		f:write(vim.json.encode({ version = 1, repos = { %q, "/external/repoB" } }))
		f:close()
	]]):format(env.repos.A.root))
	-- 本实例再授予 C(save 应先重读合并,而非用陈旧快照覆盖)
	child.lua((IR .. ".trust_repo(%q)"):format(env.repos.C.doc))
	-- 期望:B 的授予仍在盘上
	eq(
		child.lua_get([[(function()
			local f = assert(io.open(vim.env.XDG_STATE_HOME .. "/nvim/image-remote-trust.json", "r"))
			local data = vim.json.decode(f:read("*a")); f:close()
			return vim.tbl_contains(data.repos, "/external/repoB")
		end)()]]),
		true
	)
end

-- ============================================================ #8 落盘失败即发散
-- trust_clear 先清内存再 save;save 抛错时内存已空但盘上仍有 → 重启复活。
-- 应 persist-then-clear。
T["#8 failed persist does not wipe in-memory trust"] = function()
	local env = isolate({ repos = { "A" } })
	child.lua((IR .. ".trust_repo(%q)"):format(env.repos.A.doc))
	-- 让下一次 save 失败:state 目录设只读(建不了 .tmp)
	child.lua([[vim.uv.fs_chmod(vim.env.XDG_STATE_HOME .. "/nvim", tonumber("500", 8))]])
	child.lua("pcall(" .. IR .. ".trust_clear)")
	child.lua([[vim.uv.fs_chmod(vim.env.XDG_STATE_HOME .. "/nvim", tonumber("700", 8))]]) -- 复原便于清理
	-- 期望:内存未被清空(与盘一致)
	eq(child.lua_get((IR .. ".is_trusted(%q, %q)"):format(env.repos.A.doc, URL)), true)
end

-- ============================================================ #5 占位图 cache 目录
-- ensure_placeholder 写 stdpath('cache') 前不 mkdir → fresh cache 上 magick 无处
-- 写,占位图静默缺失(本仓库 convert.notify=false + inline=true 连报错都没有)。
T["#5 blocked remote render creates its cache dir"] = function()
	isolate({})
	child.lua((IR .. ".block_remote('doc.md', %q)"):format(URL))
	eq(
		child.lua_get([[(function()
			local p = vim.fs.joinpath(vim.fn.stdpath("cache"), "snacks-image-blocked.png")
			return vim.fn.isdirectory(vim.fs.dirname(p)) == 1
		end)()]]),
		true
	)
end

return T
