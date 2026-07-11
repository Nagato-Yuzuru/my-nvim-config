-- 回归测试:每个用例对应一个代码审查确认过、已修复的 image-remote-trust bug,
-- 断言期望行为、防止回归(用例名前缀 #N 是当轮审查的 finding 编号,仅作稳定
-- 标识)。有的 finding 修法是把肇事机制整个删掉(root 负缓存、运行时生成占位
-- 图):机制没了 bug 无从复发,对应用例改为断言替代机制的契约。原 #9(未落盘
-- 文件跨 :w 的 key 漂移)随 norm_path 递归的移除不再承诺——重按 ,iaf 即恢复,
-- 用例一并删除。

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

-- ============================================================ #6 root 负缓存(已删机制)
-- 曾经:repo_root 把「非 git 目录」永久负缓存,git init 后 ,iar 仍拒绝。修复是
-- 删掉缓存本身(git_root 每次现算);本用例断言其行为契约:mid-session git init
-- 后授予立即可行,且已被渲染路径摸过的目录不受影响。
T["#6 trust_repo succeeds after git init mid-session"] = function()
	local env = isolate({})
	child.lua(
		("vim.fn.mkdir(%q, 'p'); vim.fn.writefile({'x'}, %q)"):format(env.base .. "/proj", env.base .. "/proj/doc.md")
	)
	local doc = env.base .. "/proj/doc.md"
	-- 渲染路径先摸一次(曾把该目录负缓存为「非 git」的动作)
	child.lua((IR .. ".is_trusted(%q, %q)"):format(doc, URL))
	-- 用户随后 git init
	child.lua(("vim.fn.mkdir(%q, 'p')"):format(env.base .. "/proj/.git"))
	-- 期望:现在能授予,且渲染判定同步认账
	eq(child.lua_get(("type(" .. IR .. ".trust_repo(%q))"):format(doc)), "string")
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

-- 边界:root 是 $HOME 的**祖先**同样过宽(信任面 ⊇ 整个家目录)。判定共用
-- tools/lsp_root.overbroad——LSP workspace 与 ,iar 对「过宽」的定义保持一致。
T["#2 trust_repo rejects a git root that is an ancestor of $HOME"] = function()
	local env = isolate({})
	child.lua_get(
		[[(function(base)
			vim.fn.mkdir(base .. "/wide/.git", "p")
			vim.fn.mkdir(base .. "/wide/home", "p")
			vim.fn.writefile({ "x" }, base .. "/wide/notes.md")
			vim.env.HOME = vim.uv.fs_realpath(base .. "/wide/home")
			return true
		end)(...)]],
		{ env.base }
	)
	eq(child.lua_get(("type(" .. IR .. ".trust_repo(%q))"):format(env.base .. "/wide/notes.md")), "nil")
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

-- ============================================================ #5 占位图可用性
-- 曾经:占位图运行时用 magick 生成,fresh cache 上目录缺失/spawn 失败都会让它
-- 静默神隐(convert.notify=false 连报错都没有)。修复是彻底不再运行时生成——
-- 占位图是仓库静态资产。契约:block_remote 返回的路径永远指向真实存在的本地文件。
T["#5 blocked remote render points at an existing local file"] = function()
	isolate({})
	eq(child.lua_get(("vim.uv.fs_stat(%s.block_remote('doc.md', %q)) ~= nil"):format(IR, URL)), true)
end

-- ============================================================ #12 snacks 缺席不崩
-- :ImageTrust 命令注册于 snacks 的 init(与 snacks load 解耦)。snacks 加载失败时
-- Snacks 全局为 nil,`:ImageTrust clear` → refresh_docs 遍历到已加载的 doc buffer
-- → detach 里 Snacks.image.placement.clean 索引 nil 崩溃。应 no-op 而非报错。
-- (child 里本就没加载 snacks,Snacks==nil 天然复现该环境。)
T["#12 refresh_docs no-ops when snacks is absent"] = function()
	child.lua([[
		local buf = vim.api.nvim_create_buf(true, false)
		vim.bo[buf].filetype = "markdown"
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# doc" })
	]])
	eq(child.lua_get([[Snacks == nil]]), true) -- 前提:snacks 未加载
	eq(child.lua_get("select(1, pcall(" .. IR .. ".refresh_docs))"), true)
end

-- ============================================================ #1 resolve 旁路收口
-- config.resolve 只在 doc 链上;`:e https://…png` 的 BufReadCmd、picker 图片预览
-- 等路径绕过它。所有抓取路径最终都汇聚到 snacks.image.convert.convert({src})——
-- guard_convert 在这一个函数上补 default-deny。用假 convert 模块记录 orig 收到
-- 的 src(真 convert 模块脱离 Snacks 全局加载不了,child 里必须 fake)。

-- 未获信任的远程 URL:orig 收到的应是本地占位图(不会 curl),不是原 URL。
T["#1 convert guard swaps an untrusted remote src for a local placeholder"] = function()
	isolate({})
	local got = child.lua_get([[(function()
		local captured = {}
		package.loaded["snacks.image.convert"] = { convert = function(opts) captured.src = opts.src end }
		local ir = require("tools.image_render")
		ir.guard_convert()
		require("snacks.image.convert").convert({ src = "https://evil.com/x.png" })
		return captured.src
	end)()]])
	eq(child.lua_get("type(...)", { got }), "string")
	eq(child.lua_get(IR .. ".is_remote_src(...)", { got }), false) -- 换成本地占位图 = 断网
end

-- 本地图 src 原样透传(不能误伤本地图片文件的查看)。
T["#1 convert guard passes a local image src through untouched"] = function()
	isolate({})
	local got = child.lua_get([[(function()
		local captured = {}
		package.loaded["snacks.image.convert"] = { convert = function(opts) captured.src = opts.src end }
		local ir = require("tools.image_render")
		ir.guard_convert()
		require("snacks.image.convert").convert({ src = "/local/a.png" })
		return captured.src
	end)()]])
	eq(got, "/local/a.png")
end

-- 已放行(逐图)的远程 URL 原样透传,交回原 convert 正常抓取。
T["#1 convert guard passes a session-trusted URL through untouched"] = function()
	isolate({})
	local got = child.lua_get([[(function()
		local captured = {}
		package.loaded["snacks.image.convert"] = { convert = function(opts) captured.src = opts.src end }
		local ir = require("tools.image_render")
		ir.trust_image("https://ok.com/a.png")
		ir.guard_convert()
		require("snacks.image.convert").convert({ src = "https://ok.com/a.png" })
		return captured.src
	end)()]])
	eq(got, "https://ok.com/a.png")
end

-- doc 链放行的联动:resolve(block_remote)按 (file, src) 判过并放行的远程 src
-- 记入 approved,convert 层凭此放过——文件/仓库档的图不会在 convert 再被拦死。
T["#1 convert guard passes a resolve-approved URL through"] = function()
	local env = isolate({ repos = { "A" } })
	local got = child.lua_get(([[(function()
		local captured = {}
		package.loaded["snacks.image.convert"] = { convert = function(opts) captured.src = opts.src end }
		local ir = require("tools.image_render")
		ir.trust_repo(%q)
		assert(ir.block_remote(%q, %q) == nil, "resolve should allow the repo-trusted src")
		ir.guard_convert()
		require("snacks.image.convert").convert({ src = %q })
		return captured.src
	end)()]]):format(env.repos.A.doc, env.repos.A.doc, URL, URL))
	eq(got, URL)
end

-- 档位边界:仓库档信任**不外溢**到无文档上下文的路径——同一 URL 未经 resolve
-- 放行(approved 为空)、也无逐图授予时,convert 层维持拦截。
T["#1 convert guard still blocks a repo-trusted URL outside doc context"] = function()
	local env = isolate({ repos = { "A" } })
	local got = child.lua_get(([[(function()
		local captured = {}
		package.loaded["snacks.image.convert"] = { convert = function(opts) captured.src = opts.src end }
		local ir = require("tools.image_render")
		ir.trust_repo(%q)
		ir.guard_convert()
		require("snacks.image.convert").convert({ src = %q })
		return captured.src
	end)()]]):format(env.repos.A.doc, URL))
	eq(child.lua_get(IR .. ".is_remote_src(...)", { got }), false)
end

-- ============================================================ #4/#10 ,iai 直取 src
-- ,iai 不再靠 reveal_active 哨兵穿过渲染管线,而是直接跑 "images" treesitter query
-- 现取光标处 image 的原始 src。这消除了并发泄漏 / session 卡死(#4)与哨兵伪造
-- (#10)。snacks 在 rtp 上,但它 markdown_inline 的 query 文件用 #gsub! 指令
-- (nvim-treesitter 注册,child 里没有,query.get 读文件会报错)——用 query.set
-- 挂一个同形无指令的覆盖,顺带保证用例不随上游 query 内容漂移。

-- 正例:光标落在被拦远程图上 → 放行的正是它的原始 URL,且不波及别的 URL。
T["#4 iai grants exactly the raw URL of the image at the cursor"] = function()
	isolate({})
	child.lua([[
		vim.treesitter.query.set("markdown_inline", "images", "(image (link_destination) @image.src) @image")
		local b = vim.api.nvim_create_buf(true, false)
		vim.bo[b].filetype = "markdown"
		vim.api.nvim_buf_set_lines(b, 0, -1, false, { "![x](https://example.com/a.png)" })
		vim.api.nvim_set_current_buf(b)
		vim.api.nvim_win_set_cursor(0, { 1, 6 })
	]])
	child.lua(IR .. ".trust_image_at_cursor()")
	eq(child.lua_get(IR .. ".is_trusted('', 'https://example.com/a.png')"), true)
	eq(child.lua_get(IR .. ".is_trusted('', 'https://other.com/b.png')"), false)
end

-- 边界:光标不在图那一行 → 什么都不放行(行级取址不外溢)。
T["#4 iai off the image's line grants nothing"] = function()
	isolate({})
	child.lua([[
		vim.treesitter.query.set("markdown_inline", "images", "(image (link_destination) @image.src) @image")
		local b = vim.api.nvim_create_buf(true, false)
		vim.bo[b].filetype = "markdown"
		vim.api.nvim_buf_set_lines(b, 0, -1, false, { "text line", "![x](https://example.com/a.png)" })
		vim.api.nvim_set_current_buf(b)
		vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- 图在第 2 行,光标在第 1 行
	]])
	child.lua(IR .. ".trust_image_at_cursor()")
	eq(child.lua_get(IR .. ".is_trusted('', 'https://example.com/a.png')"), false)
end

-- ============================================================ #13 transform 对齐
-- snacks 对部分语言在 resolve 前重写 src(norg:节点起点到行尾整段)——,iai 的
-- key 必须走同一条流水线,否则授予的 key 与 block_remote 收到的对不上、放行静默
-- 失效。src_at_cursor 直接调 snacks 的 doc.transforms;此处给 markdown_inline 注
-- 入一个假 transform(child 进程级隔离,不污染别的用例)验证流水线确实过它。
T["#13 iai src pipeline applies snacks per-language transforms"] = function()
	isolate({})
	child.lua([[
		vim.treesitter.query.set("markdown_inline", "images", "(image (link_destination) @image.src) @image")
		require("snacks.image.doc").transforms.markdown_inline = function(img) img.src = img.src .. "?sig=1" end
		local b = vim.api.nvim_create_buf(true, false)
		vim.bo[b].filetype = "markdown"
		vim.api.nvim_buf_set_lines(b, 0, -1, false, { "![x](https://example.com/a.png)" })
		vim.api.nvim_set_current_buf(b)
		vim.api.nvim_win_set_cursor(0, { 1, 6 })
	]])
	child.lua(IR .. ".trust_image_at_cursor()")
	-- 放行的 key 是 transform 后的形态,不是裸节点文本
	eq(child.lua_get(IR .. ".is_trusted('', 'https://example.com/a.png?sig=1')"), true)
	eq(child.lua_get(IR .. ".is_trusted('', 'https://example.com/a.png')"), false)
end

return T
