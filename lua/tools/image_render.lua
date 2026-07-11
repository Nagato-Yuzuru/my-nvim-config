---
--- snacks.image 图片渲染开关。snacks 没有官方的 per-buffer / 全局 on-off
--- API,这里通过它的内部机制实现,**所有对 snacks 内部命名的依赖集中在
--- 本模块**(snacks 更新后只需复查这一处):
---   * augroup:  "snacks.image.inline."..buf / "snacks.image.doc."..buf
---   * 重入锁:  vim.b[buf].snacks_image_attached(doc._attach 的守卫,
---              置 true 可让后续 attach 直接 no-op —— 即"禁用")
---   * 全局闸:  Snacks.image.config.enabled(doc.attach 的第一道检查)
--- 自有状态用 vim.b[buf].image_render_off 记录(不能复用 attach 守卫做
--- toggle 判断:守卫在"渲染中"和"已禁用"两态下都是 true)。
---
--- 本模块还持有**远程图片安全策略**:snacks 对任何 `scheme://` 图片 src 会
--- 自动 `curl -L` 拉取(跟随重定向、不校验 content-type)=「打开一份文档就
--- 自动向里面写的任意主机发请求」——tracking pixel 泄露 IP、以及跳内网 /
--- 169.254.169.254 的 SSRF 面。两道闸,默认全拦、命中信任才放行:
---   1. M.block_remote 挂 config.resolve(file, src)(snacks 官方钩子,doc
---      内联与 ,iv hover 都过它):远程且未获信任 → 换本地占位图;信任命中
---      → 记入 approved 后交回 snacks。这是唯一拿得到 (file, src) 文档上下
---      文的地方,文件/仓库档只能在此判定。
---   2. M.guard_convert 包住 snacks.image.convert.convert——所有抓取路径
---      (doc 渲染、`:e https://…png` 的 BufReadCmd、picker 图片预览)最终
---      都汇聚到这一个函数,curl 只从这个模块发出。approved / 逐图档之外
---      的远程 src 一律换占位图:兜住 resolve 覆盖不到的路径,也兜住
---      snacks 未来新增的抓取路径(失效模式是 fail-closed,不是悄悄联网)。
---
--- 放行走三档信任(,ia*)——粒度与来源边界的可信度对齐。范式参照
--- vim.secure(default-deny + per-path 显式授予 + 落 state)但不依赖它
--- (信任「项目代码」≠ 信任「项目的远程图」):
---   图   ,iai  key=精确 URL     session 内存(一次性决定,用完即弃)
---   文件 ,iaf  key=realpath     session 内存(路径稳定但内容会漂移,
---              session 寿命把漂移窗压到最小,故不持久化)
---   仓库 ,iar  key=git root 的 realpath,持久
---              stdpath("state")/image-remote-trust.json(稳定信任边界,
---              值得记住;过宽 root——文件系统根 / $HOME 及其祖先——拒绝
---              授予,判定与 LSP root 共用 tools/lsp_root.overbroad,
---              非 git 目录同样拒绝、绝不退回 cwd)
--- 持久库原子写、损坏时按空库 + WARN(fail-safe:读不出=谁都不信)。
--- 审计/撤销::ImageTrust [list|clear](lua/plugins/ui/snacks.lua 注册)。
---
--- 对 snacks 内部的依赖同顶部原则集中在本模块;snacks 未 pin,:Lazy update
--- 后复查这份清单:convert.convert 的 opts.src 契约(guard_convert)、
--- resolve 收到的 src 已 url_decode、"images" query 与 "image.src" capture、
--- doc.transforms / doc.url_decode(直接调用其函数,不复制)、is_uri 的
--- `^%w%w+://` 模式(此一处是镜像:convert 模块脱离 Snacks 全局加载不了,
--- 而 is_remote_src 要在无 snacks 的测试子进程里独立可跑)。
---
--- 引用方:lua/plugins/lang/markdown.lua(,mr/,mR 联动)、
---         lua/plugins/ui/snacks.lua(,ii 开关 / ,it inline-float 切换、
---         ,ia* 放行三键 + :ImageTrust、image.resolve = block_remote、
---         setup 后调 guard_convert)。
---

local M = {}

--- snacks.image doc 覆盖的文档 filetype(与 snacks.lua 键位的 ft 一致)
M.doc_fts = { "markdown", "markdown.mdx", "tex", "typst", "norg" }

--- snacks.image 是否已加载可用。:ImageTrust 命令注册于 snacks 的 init、与 snacks
--- load 解耦,snacks 加载失败时 Snacks 全局为 nil——依赖它重挂/清占位的操作应
--- no-op 而非索引 nil 崩溃(见 test #12)。
---@return boolean
local function image_ready() return Snacks ~= nil and Snacks.image ~= nil end

---@param buf integer
local function detach(buf)
	pcall(vim.api.nvim_del_augroup_by_name, "snacks.image.inline." .. buf)
	pcall(vim.api.nvim_del_augroup_by_name, "snacks.image.doc." .. buf)
	Snacks.image.placement.clean(buf)
	vim.b[buf].snacks_image_attached = true
end

---@param buf? integer nil/0 = 当前 buffer
---@return integer
local function norm_buf(buf) return (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf end

--- 遍历所有已加载的文档 buffer(doc_fts filetype),对每个调用 fn(buf)。
--- global_set(全局开关)与 refresh_docs(信任变化重渲)共用这段筛选。
---@param fn fun(buf: integer)
local function for_each_doc_buf(fn)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.tbl_contains(M.doc_fts, vim.bo[buf].filetype) then
			fn(buf)
		end
	end
end

--- buffer 级图片渲染开关。全局闸关着时开 buffer 级无效(attach 会 no-op)。
---@param buf? integer
---@param on? boolean nil = toggle
---@return boolean on 设置后的状态
function M.buf_set(buf, on)
	buf = norm_buf(buf)
	if on == nil then
		on = vim.b[buf].image_render_off == true
	end
	detach(buf)
	if on then
		vim.b[buf].image_render_off = nil
		vim.b[buf].snacks_image_attached = nil
		Snacks.image.doc.attach(buf)
	else
		vim.b[buf].image_render_off = true
	end
	return on
end

--- 全局图片渲染开关:翻 config.enabled 管住未来 buffer,再逐一处理
--- 已加载的文档 buffer。
---@param on? boolean nil = toggle
---@return boolean on 设置后的状态
function M.global_set(on)
	if on == nil then
		on = Snacks.image.config.enabled == false
	end
	Snacks.image.config.enabled = on
	for_each_doc_buf(function(buf) M.buf_set(buf, on) end)
	return on
end

--- 清占位并重挂当前 buffer,让改过的 doc 配置(如 inline↔float)立即生效。
---@param buf? integer
function M.buf_refresh(buf)
	buf = norm_buf(buf)
	detach(buf)
	vim.b[buf].image_render_off = nil
	vim.b[buf].snacks_image_attached = nil
	Snacks.image.doc.attach(buf)
end

-- ── 远程图片拦截(安全)──────────────────────────────────────────────

--- src 是否是 snacks 会自动 curl 的网络 URL:镜像 snacks is_uri
--- (convert.lua 的 `^%w%w+://`),但放行本地 file://。
---@param src string
---@return boolean
function M.is_remote_src(src)
	local scheme = src:match("^(%w%w+)://")
	-- RFC 3986: scheme 大小写不敏感,故 FILE:// 也是本地——比较前先降为小写,
	-- 否则大写 file scheme 会被误判为远程而拦掉(见 test #11)。
	return scheme ~= nil and scheme:lower() ~= "file"
end

local uv = vim.uv or vim.loop

-- 「远程图已拦截」占位图:仓库里的静态资产(220x44 深底红叉,纯几何、无文字,
-- 明暗背景都读得出),路径即常量——不在运行时生成,渲染路径上零 spawn / 零
-- mkdir / 零阻塞。关键契约:block_remote 永远返回这个本地路径,**绝不回退成
-- 联网抓取**。
local placeholder_png =
	vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), "assets", "image-blocked.png")

-- ── 远程图片信任分级(,ia* 放行)─────────────────────────────────────

-- 三档信任集(尺度/寿命/键见模块头注释)。仓库档惰性从磁盘加载。
local trusted_images = {} ---@type table<string, true> key: 精确 URL(snacks url_decode 后的形态)
local trusted_files = {} ---@type table<string, true> key: realpath
local trusted_repos ---@type table<string, true>? nil = 尚未加载

-- resolve 已放行的远程 src(session)。guard_convert 没有 (file, src) 文档上下文,
-- 文件/仓库档的判定只能发生在 block_remote;它放行时记到这里,convert 层凭此
-- 放过同一 src。单调增、trust_clear 时清空——撤销后下一次 resolve 不再补记,
-- 重渲即回到拦截态。
local approved = {} ---@type table<string, true>

--- 与 vim.secure 同款的键归一化:解符号链接,同一实体只有一个 key。路径尚未
--- 落盘时(如 ,iaf 授予一个还没 :w 的文件)退回 normalize——文件档本就是
--- session 级,极端情况(符号链接目录下的未保存文件,:w 后 key 漂移)重按
--- 一次 ,iaf 即恢复,不为它付「递归上溯最深存在祖先」的复杂度。
---@param p string
---@return string
local function norm_path(p)
	local n = vim.fs.normalize(p)
	return uv.fs_realpath(n) or n
end

--- file 所在的 git 仓库 root(已 realpath 归一)。过宽的 root——文件系统根、
--- $HOME 及其祖先——返回 nil:dotfiles-as-repo(~/.git)会让 vim.fs.root 一路
--- 冒泡到家目录,授予它等于信任整个家目录下所有文档的远程图(见 test #2)。
--- 不做缓存:is_trusted 的零授予快路径已挡住常态,vim.fs.root 只是一次向上
--- stat 走查;负缓存曾让「git init 前被摸过的目录」永久挡在门外(见 test #6)。
---@param dir string 已 norm_path 归一的目录
---@return string?
local function git_root(dir)
	local root = vim.fs.root(dir, ".git")
	if not root then
		return nil
	end
	root = norm_path(root)
	if require("tools.lsp_root").overbroad(root) then
		return nil
	end
	return root
end

-- 每次调用取 stdpath:测试经 $XDG_STATE_HOME 隔离持久层(stdpath 读 env 是活的)。
-- 暴露给测试引用真实路径(单一事实源,免测试硬编码文件名)。
function M.state_file() return vim.fs.joinpath(vim.fn.stdpath("state"), "image-remote-trust.json") end

--- 从磁盘现读持久仓库集(不走内存缓存)。fail-safe:文件缺失 → 空集;损坏 →
--- 空集 + WARN(**默认拒绝**,绝不因读失败而放行)。写盘前用它重读+合并,是多实例
--- (tmux)并发授予不互相覆盖丢更新的关键(见 test #3)。
---@return table<string, true>
local function read_disk_repos()
	local set = {}
	local f = io.open(M.state_file(), "r")
	if not f then
		return set
	end
	local raw = f:read("*a")
	f:close()
	local ok, data = pcall(vim.json.decode, raw)
	if ok and type(data) == "table" and type(data.repos) == "table" then
		for _, r in ipairs(data.repos) do
			if type(r) == "string" then
				set[r] = true
			end
		end
	else
		vim.notify(
			"Image trust: trust store corrupt, treating as empty (default-deny): " .. M.state_file(),
			vim.log.levels.WARN
		)
	end
	return set
end

--- 惰性把持久库读进内存(一进程一次)。热路径判定读它;写路径改走 read_disk_repos
--- 现读并集,避免用陈旧内存快照覆盖别的实例的授予。
---@return table<string, true>
local function load_repos()
	if not trusted_repos then
		trusted_repos = read_disk_repos()
	end
	return trusted_repos
end

--- 原子写给定集合到持久库(临时文件 + rename),排序保证内容稳定。写失败抛错
--- ——调用方靠它实现 persist-then-commit:写盘成功了才改内存,失败则内存/盘不发散
--- (见 test #8)。tmp 用固定名:授予是人手速级别的低频操作,两实例同毫秒写同
--- 一个 tmp 的窗口不值得为它维护 pid/序号拼名。
---@param set table<string, true>
local function persist_repos(set)
	local repos = vim.tbl_keys(set)
	table.sort(repos)
	local path = M.state_file()
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	local tmp = path .. ".tmp"
	local f = assert(io.open(tmp, "w"))
	f:write(vim.json.encode({ version = 1, repos = repos }))
	f:close()
	local ok, err = uv.fs_rename(tmp, path)
	if not ok then
		os.remove(tmp)
		error(err)
	end
end

--- (file, src) 是否命中任一信任档。unnamed buffer(file == "")只认逐图档
--- ——scratch 内容与磁盘来源无关,不该继承 cwd 所在仓库的信任。
---@param file string
---@param src string 远程 URL(调用方已保证 is_remote_src)
---@return boolean
function M.is_trusted(file, src)
	if trusted_images[src] then
		return true
	end
	if file == "" then
		return false
	end
	-- 零授予快路径:文件档与仓库档皆空时,免掉后面每图一次的 norm_path/git_root
	-- 系统调用(未放行文档是常态,这条最热)。trusted_images 上面已查过。
	local repos = load_repos()
	if not next(trusted_files) and not next(repos) then
		return false
	end
	local norm = norm_path(file)
	if trusted_files[norm] then
		return true
	end
	local root = git_root(vim.fs.dirname(norm))
	return root ~= nil and repos[root] == true
end

--- 放行一张图(session)。key 为精确 URL——一张就是一张。
---@param url string
function M.trust_image(url) trusted_images[url] = true end

--- 放行一个文件(session)。返回归一化后的 key;file 为空返回 nil。
---@param file string
---@return string?
function M.trust_file(file)
	if file == "" then
		return nil
	end
	local key = norm_path(file)
	trusted_files[key] = true
	return key
end

--- 放行 file 所在 git 仓库(持久,落 state)。不在 git 仓库返回 nil,
--- 由调用方提示改用 ,iaf/,iai。
---@param file string
---@return string? root
function M.trust_repo(file)
	if file == "" then
		return nil
	end
	local root = git_root(vim.fs.dirname(norm_path(file)))
	if not root then
		return nil
	end
	-- persist-then-commit(#8)+ 并发合并(#3):把「磁盘 ∪ 内存 ∪ {root}」先写盘成功,
	-- 再并入内存;写盘失败则内存不动、盘/内存不发散。合并保留:tmux 多实例是日常
	-- 工作形态,另一实例的持久授予不该被本实例的陈旧快照覆盖。
	local merged = vim.tbl_extend("force", read_disk_repos(), load_repos())
	merged[root] = true
	persist_repos(merged)
	trusted_repos = merged
	return root
end

-- ,iai 的取址难点:渲染管线里远程 URL 已被 block_remote 换成占位图,直接问 snacks
-- 「光标处是什么」只能拿到占位图路径。改为**直接跑 snacks 装的 "images" treesitter
-- query**(所有 doc 语言通用)现取光标处 image 节点的原始 src——同步、无全局标志、
-- 无哨兵,免掉旧 reveal_active 方案的并发泄漏 / session 卡死(#4)与哨兵伪造(#10)。
-- 对 snacks 内部命名(query 名 "images"、capture "image.src")的又一处耦合,集中于此。

--- 光标所在行 image 节点的原始 src(未经 block_remote 改写),无则 nil。
--- key 必须与 block_remote 收到的 src 逐字节一致,故镜像 doc._img 的 src 流水线:
--- 节点文本 → per-language transform(norg 会把 src 重写成「节点起点到行尾」,
--- 见 test #13)→ url_decode(resolve 在调 config.resolve 前先解码)。transform
--- 与 url_decode 直接调 snacks.image.doc 的原函数(该模块不碰 Snacks 全局、可
--- 独立 require),不本地复制——snacks 改解码/transform 规则时两端同步漂移。
---@return string?
local function src_at_cursor()
	local sdoc = require("snacks.image.doc")
	local buf = vim.api.nvim_get_current_buf()
	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not ok or not parser then
		return nil
	end
	parser:parse(true)
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1 -- 0-based
	local found ---@type string?
	parser:for_each_tree(function(tstree, tree)
		if found or not tstree then
			return
		end
		local lang = tree:lang()
		local query = vim.treesitter.query.get(lang, "images")
		if not query then
			return
		end
		for _, match, meta in query:iter_matches(tstree:root(), buf, row, row + 1) do
			for id, nodes in pairs(match) do
				if query.captures[id] == "image.src" then
					local node = type(nodes) == "userdata" and nodes or nodes[#nodes]
					local img = { src = vim.treesitter.get_node_text(node, buf, { metadata = meta[id] }), lang = lang }
					local transform = sdoc.transforms[lang]
					if transform then
						transform(
							img,
							{ buf = buf, lang = lang, meta = meta, src = { node = node, meta = meta[id] or {} } }
						)
					end
					if img.src then
						found = (sdoc.url_decode(img.src))
					end
					return
				end
			end
		end
	end)
	return found
end

--- ,iai:放行光标处那张被拦的远程图(session),成功后立即重渲。
function M.trust_image_at_cursor()
	local src = src_at_cursor()
	if not (src and M.is_remote_src(src)) then
		vim.notify("Image trust: no blocked remote image at cursor", vim.log.levels.WARN)
		return
	end
	-- file 传当前 buffer 名:该图可能已经由文件/仓库档信任,这时提示「已放行」而非
	-- 冗余地再记一条逐图授予。
	if M.is_trusted(vim.api.nvim_buf_get_name(0), src) then
		vim.notify("Image trust: this image is already allowed")
		return
	end
	M.trust_image(src)
	M.refresh_docs()
	vim.notify("Image trust: allowed (session) " .. src)
end

--- ,iaf:放行当前 buffer 文件(session),成功后重渲;buffer 无文件名则告警。
--- (grant+notify+refresh 的编排住模块里,snacks spec 只 delegate,保持声明式。)
function M.grant_file_interactive()
	local key = M.trust_file(vim.api.nvim_buf_get_name(0))
	if key then
		M.refresh_docs()
		vim.notify("Image trust: file allowed (session) " .. key)
	else
		vim.notify("Image trust: buffer has no file name", vim.log.levels.WARN)
	end
end

--- ,iar:持久放行当前 buffer 所在 git 仓库,成功后重渲;不在 git 仓库或 root
--- 过宽($HOME 及其祖先)则告警。
function M.grant_repo_interactive()
	local root = M.trust_repo(vim.api.nvim_buf_get_name(0))
	if root then
		M.refresh_docs()
		vim.notify("Image trust: repo allowed (persistent) " .. root)
	else
		vim.notify("Image trust: no git repo here (or root too broad, e.g. ~) — use ,iaf/,iai", vim.log.levels.WARN)
	end
end

--- :ImageTrust list 的内容:三档信任的可审计快照。
---@return string[]
function M.trust_list()
	local lines = { "Image trust (allowed remote images):" }
	---@param title string
	---@param set table<string, true>
	local function section(title, set)
		local keys = vim.tbl_keys(set)
		table.sort(keys)
		lines[#lines + 1] = ("  %s(%d):"):format(title, #keys)
		for _, k in ipairs(keys) do
			lines[#lines + 1] = "    " .. k
		end
	end
	section("images (session)", trusted_images)
	section("files (session)", trusted_files)
	section("repos (persistent " .. M.state_file() .. ")", load_repos())
	return lines
end

--- 清空三档信任并把持久库改写为空。调用方负责 refresh_docs。
function M.trust_clear()
	-- persist-then-commit(#8):先把空库写盘成功,再清内存三集;写盘失败(如 state
	-- 目录只读)则抛错传出、内存不动,避免盘上仍有而内存已空的发散。
	persist_repos({})
	trusted_images, trusted_files, trusted_repos, approved = {}, {}, {}, {}
end

--- 重渲所有已加载文档 buffer(跳过被 ,ii 手动关掉的),让信任变化立即生效
--- ——仓库/URL 级放行可能影响多个 buffer,不止当前。
function M.refresh_docs()
	if not image_ready() then
		return
	end
	for_each_doc_buf(function(buf)
		if not vim.b[buf].image_render_off then
			M.buf_refresh(buf)
		end
	end)
end

--- Snacks.image.config.resolve 钩子:远程且未获信任的 src → 本地占位图
--- (不联网);信任命中 → 记入 approved(guard_convert 凭此放行)后返回 nil
--- (交回 snacks 用原 URL 抓取);本地 → nil。见模块头注释的安全策略段。
---@param file string
---@param src string
---@return string?
function M.block_remote(file, src)
	if not M.is_remote_src(src) then
		return nil
	end
	if M.is_trusted(file, src) then
		approved[src] = true
		return nil
	end
	return placeholder_png
end

--- 抓取的单一收口:所有路径(doc 内联 / hover、`:e https://…png` 的 BufReadCmd、
--- picker 图片预览)最终都汇聚到 snacks.image.convert.convert({src}),curl 只从
--- 那个模块发出——在这里包一层 default-deny,未获批的远程 src 换成本地占位图,
--- 则**任何**现在或未来的 snacks 抓取路径都拿不到未信任 URL。放行两种:resolve
--- 已按 (file, src) 判过并记入 approved 的;逐图档命中的(裸 URL buffer / picker
--- 无文档上下文,只认这一档——文件/仓库档是「某文档信任其内嵌图」,与之无关)。
--- 幂等(重复调用只 patch 一次)。由 snacks.lua 在 setup 后调用。
function M.guard_convert()
	local convert = require("snacks.image.convert")
	if convert._image_render_guarded then
		return
	end
	convert._image_render_guarded = true
	local orig = convert.convert
	---@param opts { src: string }
	convert.convert = function(opts)
		if M.is_remote_src(opts.src) and not approved[opts.src] and not M.is_trusted("", opts.src) then
			opts = vim.tbl_extend("force", opts, { src = placeholder_png })
		end
		return orig(opts)
	end
end

return M
