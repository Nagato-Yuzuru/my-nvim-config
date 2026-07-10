-- lua/tools/image_render.lua 的远程拦截安全策略测试。核心是 is_remote_src
-- (哪些 src 会被 snacks 自动 `curl` = 编辑器的对外网络面)与 is_trusted
-- (三档放行判定)——均可在 child 里直接调用,无需 Snacks/magick。
-- block_remote 只验接线:本地 → nil、远程 → 占位图路径(生成走 magick,
-- pcall 兜底,故断言只看返回契约、不依赖 magick 是否在场)。
-- 持久层经 $XDG_STATE_HOME 指到临时目录隔离(stdpath 读 env 是活的,
-- 模块每次 save/load 都现取 stdpath),不碰真实 state。

local H = require("tests.helpers")
local child, hooks = H.new_child()

local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality
local IR = "require('tools.image_render')"

local function is_remote(src) return child.lua_get((IR .. ".is_remote_src(%q)"):format(src)) end
-- 返回值可能是 nil,child.lua_get 会把它变 vim.NIL——统一用 type() 断言消歧。
-- 先把 state/cache 隔离到临时目录:否则 block_remote('doc.md',…) 会读**真实**
-- 持久库、且 repo_root('doc.md') 解析到本仓库——一旦你 ,iar 信任过 ~/.config/nvim,
-- 「remote → 占位图」这条断言就会翻红(环境耦合)。
local function block_type(src)
	return child.lua_get(([[(function()
			local base = vim.fn.tempname()
			vim.env.XDG_STATE_HOME = base .. "/state"
			vim.env.XDG_CACHE_HOME = base .. "/cache"
			return type(require('tools.image_render').block_remote('doc.md', %q))
		end)()]]):format(src))
end

-- ======================================================= is_remote_src:正例
-- 会被 snacks 自动 curl 的网络 scheme —— 必须判为 remote(拦)。
T["is_remote_src: network URLs are remote"] = MiniTest.new_set({
	parametrize = {
		{ "http://example.com/a.png" },
		{ "https://example.com/a.png" },
		{ "ftp://host/a.png" }, -- curl 也吃 ftp,同样是对外请求
		{ "HTTP://EXAMPLE.COM/a.png" }, -- 大写 scheme 照样拦
	},
})
T["is_remote_src: network URLs are remote"]["blocks"] = function(src) eq(is_remote(src), true) end

-- ======================================================= is_remote_src:反例
-- 本地引用 —— 判为非 remote(放行,交回 snacks 正常本地解析)。
T["is_remote_src: local refs are not remote"] = MiniTest.new_set({
	parametrize = {
		{ "file:///home/u/a.png" }, -- file:// 是本地读,不是网络面
		{ "./assets/a.png" },
		{ "/abs/path/a.png" },
		{ "img/a.png" },
	},
})
T["is_remote_src: local refs are not remote"]["allows"] = function(src) eq(is_remote(src), false) end

-- ==================================================== is_remote_src:边界
T["is_remote_src: boundaries"] = MiniTest.new_set()

-- 空串:无 scheme → 非 remote。
T["is_remote_src: boundaries"]["empty string is local"] = function() eq(is_remote(""), false) end

-- 单字符 scheme `a://`:snacks is_uri 要 `%w%w+`(≥2),根本不当 uri、不会
-- curl —— 镜像它,判非 remote,避免比 snacks 更激进地误拦本地路径。
T["is_remote_src: boundaries"]["single-char scheme mirrors snacks (not remote)"] = function()
	eq(is_remote("a://x"), false)
end

-- data: 内联图无 `://` —— 非 remote(snacks 另有 data_img 分支处理)。
T["is_remote_src: boundaries"]["data uri is not remote"] = function() eq(is_remote("data:image/png;base64,AAAA"), false) end

-- ========================================================= block_remote:接线
T["block_remote"] = MiniTest.new_set()

-- 远程 → 返回字符串(占位图路径);magick 缺席时 pcall 兜底仍返回路径。
T["block_remote: remote src returns a placeholder path (string)"] = function()
	eq(block_type("https://example.com/a.png"), "string")
end

-- 本地 → nil,交回 snacks 本地解析,不触发占位。
T["block_remote: local src returns nil"] = function() eq(block_type("./a.png"), "nil") end

-- ==================================================== is_trusted:三档放行
-- child 侧夹具:临时目录 + $XDG_STATE_HOME 隔离,可选造一个「git 仓库」
-- (.git 目录足矣,repo_root 只认 marker 不跑 git)。返回各路径(已 realpath,
-- 便于与模块的归一化 key 直接比较)。
local function setup_trust_env(with_repo)
	return child.lua_get(
		[[(function(with_repo)
			local tmp = vim.fn.tempname()
			vim.fn.mkdir(tmp, "p")
			tmp = vim.uv.fs_realpath(tmp)
			vim.env.XDG_STATE_HOME = tmp .. "/state"
			local env = { tmp = tmp }
			if with_repo then
				env.repo = tmp .. "/repo"
				vim.fn.mkdir(env.repo .. "/.git", "p")
				vim.fn.mkdir(env.repo .. "/docs", "p")
				env.doc = env.repo .. "/docs/note.md"
				vim.fn.writefile({ "x" }, env.doc)
			end
			return env
		end)(...)]],
		{ with_repo == true }
	)
end
local URL = "https://example.com/a.png"
local function trusted(file, src) return child.lua_get((IR .. ".is_trusted(%q, %q)"):format(file, src)) end

T["is_trusted"] = MiniTest.new_set()

-- 反例:三集皆空 → 一律不信。
T["is_trusted: empty sets deny everything"] = function()
	setup_trust_env(false)
	eq(trusted("/tmp/a.md", URL), false)
end

-- 正例:逐图档按精确 URL 命中,与 file 无关。
T["is_trusted: granted image URL matches in any file"] = function()
	setup_trust_env(false)
	child.lua((IR .. ".trust_image(%q)"):format(URL))
	eq(trusted("/tmp/a.md", URL), true)
	eq(trusted("/elsewhere/b.md", URL), true)
end

-- 边界:精确匹配——fragment / 大小写不同即不是同一张。
T["is_trusted: image grant is exact (fragment/case differ = miss)"] = function()
	setup_trust_env(false)
	child.lua((IR .. ".trust_image(%q)"):format(URL))
	eq(trusted("/tmp/a.md", URL .. "#frag"), false)
	eq(trusted("/tmp/a.md", "https://EXAMPLE.com/a.png"), false)
end

-- 正例:文件档 realpath 归一化——经符号链接访问同一文件也命中。
T["is_trusted: granted file matches through symlink (realpath key)"] = function()
	local env = setup_trust_env(true)
	child.lua((IR .. ".trust_file(%q)"):format(env.doc))
	eq(trusted(env.doc, URL), true)
	local link = env.tmp .. "/link.md"
	child.lua(("vim.uv.fs_symlink(%q, %q)"):format(env.doc, link))
	eq(trusted(link, URL), true)
	-- 反例:同仓库其它文件不沾光(文件档不外溢)
	eq(trusted(env.repo .. "/docs/other.md", URL), false)
end

-- 反例:trust_file 拒绝空文件名(unnamed buffer 无档可放)。
T["is_trusted: trust_file rejects empty name"] = function()
	setup_trust_env(false)
	eq(child.lua_get("type(" .. IR .. [[.trust_file(""))]]), "nil")
end

-- 正例:仓库档 git root 命中,覆盖仓库内所有文件;仓库外不命中。
T["is_trusted: granted repo covers files inside, not outside"] = function()
	local env = setup_trust_env(true)
	local root = child.lua_get((IR .. ".trust_repo(%q)"):format(env.doc))
	eq(root, env.repo)
	eq(trusted(env.doc, URL), true)
	eq(trusted(env.repo .. "/README.md", URL), true)
	eq(trusted(env.tmp .. "/outside.md", URL), false)
end

-- 边界:非 git 目录 trust_repo 拒绝授予(nil,绝不退回 cwd)。
T["is_trusted: trust_repo outside git returns nil"] = function()
	local env = setup_trust_env(false)
	local out = env.tmp .. "/plain.md"
	child.lua(("vim.fn.writefile({ 'x' }, %q)"):format(out))
	eq(child.lua_get(("type(" .. IR .. ".trust_repo(%q))"):format(out)), "nil")
end

-- 边界:unnamed buffer(file == "")只认逐图档——不继承 cwd 仓库的信任。
T["is_trusted: unnamed buffer only honors image grants"] = function()
	local env = setup_trust_env(true)
	child.lua((IR .. ".trust_repo(%q)"):format(env.doc))
	eq(trusted("", URL), false)
	child.lua((IR .. ".trust_image(%q)"):format(URL))
	eq(trusted("", URL), true)
end

-- ============================================ ,iaf/,iar 交互放行(读当前 buffer)
-- spec 键位只 delegate 到这两个;编排(读 buffer 名 + grant + refresh + notify)住模块。
T["grant"] = MiniTest.new_set()

-- 正例:,iaf 放行当前 buffer 的文件。
T["grant: grant_file_interactive trusts the current buffer's file"] = function()
	local env = setup_trust_env(true)
	child.lua(([[
		local b = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(b, %q)
		vim.api.nvim_set_current_buf(b)
		require("tools.image_render").grant_file_interactive()
	]]):format(env.doc))
	eq(trusted(env.doc, URL), true)
end

-- 反例:unnamed buffer 无档可放 → 不放行、不报错。
T["grant: grant_file_interactive on an unnamed buffer is a no-op, not an error"] = function()
	setup_trust_env(false)
	local ok = child.lua_get([[select(1, pcall(function()
		vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
		require("tools.image_render").grant_file_interactive()
	end))]])
	eq(ok, true)
	eq(trusted("/tmp/whatever.md", URL), false)
end

-- 正例:,iar 放行当前 buffer 所在 git 仓库(覆盖仓库内其它文件)。
T["grant: grant_repo_interactive trusts the current buffer's git repo"] = function()
	local env = setup_trust_env(true)
	child.lua(([[
		local b = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(b, %q)
		vim.api.nvim_set_current_buf(b)
		require("tools.image_render").grant_repo_interactive()
	]]):format(env.doc))
	eq(trusted(env.repo .. "/README.md", URL), true)
end

-- ==================================================== 持久层:落盘/加载
T["persistence"] = MiniTest.new_set()

-- 正例:round-trip——授予落盘后,新进程(模块重载)从磁盘读回。
T["persistence: repo grant survives module reload"] = function()
	local env = setup_trust_env(true)
	child.lua((IR .. ".trust_repo(%q)"):format(env.doc))
	-- 模拟重启:卸掉模块,信任集归零,仅剩磁盘
	child.lua([[package.loaded["tools.image_render"] = nil]])
	eq(trusted(env.doc, URL), true)
	-- session 档不落盘:重载后图档消失
	child.lua([[package.loaded["tools.image_render"] = nil]])
	child.lua((IR .. ".trust_image(%q)"):format(URL))
	child.lua([[package.loaded["tools.image_render"] = nil]])
	eq(trusted("/no/repo/here.md", URL), false)
end

-- 反例:损坏的 json → 空库、不抛(fail-safe 默认拒绝)。
T["persistence: corrupt state file denies, does not error"] = function()
	local env = setup_trust_env(true)
	child.lua([[
		local f = require("tools.image_render").state_file()
		vim.fn.mkdir(vim.fs.dirname(f), "p")
		vim.fn.writefile({ "{ not json !!" }, f)
	]])
	eq(trusted(env.doc, URL), false)
end

-- 边界:trust_clear 清空三档且改写持久库;重载后仓库档也不再命中。
T["persistence: trust_clear wipes memory and disk"] = function()
	local env = setup_trust_env(true)
	child.lua(("%s.trust_repo(%q); %s.trust_image(%q)"):format(IR, env.doc, IR, URL))
	child.lua(IR .. ".trust_clear()")
	eq(trusted(env.doc, URL), false)
	child.lua([[package.loaded["tools.image_render"] = nil]])
	eq(trusted(env.doc, URL), false)
end

-- ============================================ block_remote × 信任:接线
-- 放行命中 → nil(交回 snacks 抓);未命中维持占位图。
T["block_remote: trusted remote returns nil, untrusted stays blocked"] = function()
	local env = setup_trust_env(true)
	eq(child.lua_get(("type(" .. IR .. ".block_remote(%q, %q))"):format(env.doc, URL)), "string")
	child.lua((IR .. ".trust_repo(%q)"):format(env.doc))
	eq(child.lua_get(("type(" .. IR .. ".block_remote(%q, %q))"):format(env.doc, URL)), "nil")
end

return T
