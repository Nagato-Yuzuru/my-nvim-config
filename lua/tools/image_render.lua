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
--- 本模块还持有**远程图片安全策略**(M.block_remote):snacks 的 doc 渲染
--- 对任何 `scheme://` 图片 src 会自动 `curl -L` 拉取(convert.lua 的 url
--- 步骤,inline 渲染与 ,iv hover 都过这条链),curl 跟随重定向、不校验
--- content-type。等于「打开一份文档就自动向里面写的任意主机发请求」——
--- tracking pixel 泄露 IP、以及跳内网 / 169.254.169.254 的 SSRF 面。经
--- snacks 官方钩子 config.resolve(file, src)(doc.lua:184,curl 之前调用、
--- 返回非 nil 即短路解析)把远程 src 换成本地占位图,彻底断掉自动联网。
--- resolve 全局生效,inline 与 hover 一视同仁——不存在「hover 偷偷联网」。
---
--- 放行走三档信任(,ia*;默认全拦,命中才交回 snacks 抓)——粒度与来源
--- 边界的可信度对齐。范式参照 vim.secure(default-deny + per-path 显式
--- 授予 + 落 state)但不依赖它(信任「项目代码」≠ 信任「项目的远程图」):
---   图   ,iai  key=精确 URL     session 内存(一次性决定,用完即弃)
---   文件 ,iaf  key=realpath     session 内存(路径稳定但内容会漂移,
---              session 寿命把漂移窗压到最小,故不持久化)
---   仓库 ,iar  key=git root 的 realpath,持久
---              stdpath("state")/image-remote-trust.json(稳定信任边界,
---              值得记住;非 git 目录拒绝授予——绝不退回 cwd,cwd 可能
---              是 $HOME,等于信任整个家目录)
--- 持久库原子写、损坏时按空库 + WARN(fail-safe:读不出=谁都不信)。
--- 审计/撤销::ImageTrust [list|clear](lua/plugins/ui/snacks.lua 注册)。
---
--- 引用方:lua/plugins/lang/markdown.lua(,mr/,mR 联动)、
---         lua/plugins/ui/snacks.lua(,ii 开关 / ,it inline-float 切换、
---         ,ia* 放行三键 + :ImageTrust、image.resolve = block_remote)。
---

local M = {}

--- snacks.image doc 覆盖的文档 filetype(与 snacks.lua 键位的 ft 一致)
M.doc_fts = { "markdown", "markdown.mdx", "tex", "typst", "norg" }

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
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.tbl_contains(M.doc_fts, vim.bo[buf].filetype) then
			M.buf_set(buf, on)
		end
	end
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
	return scheme ~= nil and scheme ~= "file"
end

local uv = vim.uv or vim.loop
local placeholder_path ---@type string? 首次拦截时物化并 memoize
local tried_gen = false

--- 「远程图已拦截」占位图:落磁盘缓存,一个 session 至多尝试生成一次。
--- imagemagick 本就是整条图片链的硬依赖(没它什么都渲染不了),不引入新
--- 依赖;纯几何、无文字 → 不碰字体(snacks 在 SVG 缺字体上踩过坑)。生成
--- 失败/跳过也照常返回路径:snacks 至多对该图告警一次——响亮,且关键在于
--- **永不回退成联网抓取**。
---@return string
local function ensure_placeholder()
	local path = placeholder_path or vim.fs.joinpath(vim.fn.stdpath("cache"), "snacks-image-blocked.png")
	placeholder_path = path
	if not uv.fs_stat(path) and not tried_gen and not vim.in_fast_event() then
		tried_gen = true
		-- 深色底 + 红叉 = 通用的「blocked/broken」,明暗背景都读得出。pcall 只兜
		-- spawn 失败(magick 缺席时 ENOENT 抛错);:wait 在有效 proc 上不抛。
		-- stroke/fill 分组的顺序:magick 按参数从左到右应用,画完矩形边框再叠红叉。
		local ok, proc = pcall(vim.system, {
			"magick",
			"-size",
			"220x44",
			"xc:#202020",
			"-stroke",
			"#c04040",
			"-strokewidth",
			"2",
			"-fill",
			"none",
			"-draw",
			"rectangle 2,2 217,41",
			"-draw",
			"line 2,2 217,41",
			"-draw",
			"line 217,2 2,41",
			path,
		})
		if ok then
			proc:wait(5000)
		end
	end
	return path
end

-- ── 远程图片信任分级(,ia* 放行)─────────────────────────────────────

-- 三档信任集(尺度/寿命/键见模块头注释)。仓库档惰性从磁盘加载。
local trusted_images = {} ---@type table<string, true> key: 精确 URL(snacks url_decode 后的形态)
local trusted_files = {} ---@type table<string, true> key: realpath
local trusted_repos ---@type table<string, true>? nil = 尚未加载

--- 与 vim.secure 同款的键归一化:解符号链接,同一实体只有一个 key。
--- 路径不存在时退回 normalize 结果。
---@param p string
---@return string
local function norm_path(p)
	local n = vim.fs.normalize(p)
	return uv.fs_realpath(n) or n
end

-- git root 按目录 memoize:block_remote 在渲染热路径上逐图调用,免每图上溯。
local root_cache = {} ---@type table<string, string|false>
---@param file string
---@return string?
local function repo_root(file)
	local dir = vim.fs.dirname(norm_path(file))
	local hit = root_cache[dir]
	if hit == nil then
		local root = vim.fs.root(dir, ".git")
		hit = root and norm_path(root) or false
		root_cache[dir] = hit
	end
	return hit or nil
end

-- 每次调用取 stdpath:测试经 $XDG_STATE_HOME 隔离持久层(stdpath 读 env 是活的)。
local function state_file() return vim.fs.joinpath(vim.fn.stdpath("state"), "image-remote-trust.json") end

--- 惰性读持久仓库库。fail-safe:文件缺失 → 空集;损坏 → 空集 + WARN
--- (**默认拒绝**,绝不因读失败而放行)。
---@return table<string, true>
local function load_repos()
	if trusted_repos then
		return trusted_repos
	end
	trusted_repos = {}
	local f = io.open(state_file(), "r")
	if not f then
		return trusted_repos
	end
	local raw = f:read("*a")
	f:close()
	local ok, data = pcall(vim.json.decode, raw)
	if ok and type(data) == "table" and type(data.repos) == "table" then
		for _, r in ipairs(data.repos) do
			if type(r) == "string" then
				trusted_repos[r] = true
			end
		end
	else
		vim.notify("image_render: 信任库损坏,按空库处理(默认拦截): " .. state_file(), vim.log.levels.WARN)
	end
	return trusted_repos
end

--- 原子写持久库(临时文件 + rename),排序保证稳定内容。改时即写,不等
--- VimLeave(被 kill/崩溃时不触发)。
local function save_repos()
	local repos = vim.tbl_keys(load_repos())
	table.sort(repos)
	local path = state_file()
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	local tmp = path .. ".tmp"
	local f = assert(io.open(tmp, "w"))
	f:write(vim.json.encode({ version = 1, repos = repos }))
	f:close()
	assert(uv.fs_rename(tmp, path))
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
	if trusted_files[norm_path(file)] then
		return true
	end
	local root = repo_root(file)
	return root ~= nil and load_repos()[root] == true
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
	local root = file ~= "" and repo_root(file) or nil
	if not root then
		return nil
	end
	load_repos()[root] = true
	save_repos()
	return root
end

-- ,iai 的取址难点:渲染管线里远程 URL 已被 block_remote 换成占位图,直接问
-- snacks「光标处是什么」只能拿到占位图路径。做法:置 reveal 标志后走
-- Snacks.image.doc.at_cursor(对 snacks 内部命名的又一处耦合,按本模块约定
-- 集中于此),reveal 期间 block_remote 对未信任远程 src 返回「哨兵前缀+原
-- URL」——哨兵不含 `://`、不是 URI,即便撞上并发渲染也只会被当成不存在的
-- 本地路径而报错,**不可能触发联网**;at_cursor 只找不抓,回调里解出原 URL。
local REVEAL_PREFIX = "image-trust-reveal:"
local reveal_active = false

--- ,iai:放行光标处那张被拦的远程图(session),成功后立即重渲。
function M.trust_image_at_cursor()
	reveal_active = true
	local ok, err = pcall(Snacks.image.doc.at_cursor, function(src)
		reveal_active = false
		local url = src and src:match("^" .. vim.pesc(REVEAL_PREFIX) .. "(.+)$") or nil
		if url then
			M.trust_image(url)
			M.refresh_docs()
			vim.notify("Image trust: 已放行(session) " .. url)
		elseif src and M.is_remote_src(src) then
			vim.notify("Image trust: 该图已在放行范围内")
		else
			vim.notify("Image trust: 光标处没有被拦截的远程图片", vim.log.levels.WARN)
		end
	end)
	if not ok then
		reveal_active = false
		error(err)
	end
end

--- :ImageTrust list 的内容:三档信任的可审计快照。
---@return string[]
function M.trust_list()
	local lines = { "Image trust(远程图片放行):" }
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
	section("图(session)", trusted_images)
	section("文件(session)", trusted_files)
	section("仓库(持久 " .. state_file() .. ")", load_repos())
	return lines
end

--- 清空三档信任并把持久库改写为空。调用方负责 refresh_docs。
function M.trust_clear()
	trusted_images, trusted_files, trusted_repos = {}, {}, {}
	save_repos()
end

--- 重渲所有已加载文档 buffer(跳过被 ,ii 手动关掉的),让信任变化立即生效
--- ——仓库/URL 级放行可能影响多个 buffer,不止当前。
function M.refresh_docs()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if
			vim.api.nvim_buf_is_loaded(buf)
			and vim.tbl_contains(M.doc_fts, vim.bo[buf].filetype)
			and not vim.b[buf].image_render_off
		then
			M.buf_refresh(buf)
		end
	end
end

--- Snacks.image.config.resolve 钩子:远程且未获信任的 src → 本地占位图
--- (不联网);信任命中 → nil(交回 snacks 用原 URL 抓取);本地 → nil。
--- 见模块头注释的安全策略段。
---@param file string
---@param src string
---@return string?
function M.block_remote(file, src)
	if not M.is_remote_src(src) then
		return nil
	end
	if M.is_trusted(file, src) then
		return nil
	end
	if reveal_active then
		return REVEAL_PREFIX .. src
	end
	return ensure_placeholder()
end

return M
