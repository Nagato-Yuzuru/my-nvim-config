-- Closure-driven floating preview window — 由宿主生命周期钩子驱动的浮动预览的
-- 共享实现，这套状态机的单一真相。两个调用方共用：
-- lua/plugins/ui/snacks.lua（explorer 预览，scratch 复制）与
-- lua/plugins/ui/neominimap.lua（minimap 预览，复用活 buffer）；stale 异步更新、
-- 窗口有效性、幂等 teardown 的处理只此一份。
--
-- 契约（三条硬约束）：
--   1. buffer 策略（scratch 复制 vs 复用活 buffer）是注入的 `source` 参数，
--      **不是**对调用方身份的 if/else——模块内不认识 snacks / neominimap。
--   2. 模块**不订阅任何 autocmd/事件**：生命周期归宿主，模块只暴露命令式原语
--      （show / show_auto / toggle / …）。宿主在自己的 CursorMoved / on_change /
--      FileType 回调里调这些方法。
--   3. 竞态防护（晚到的旧异步结果被丢弃）在**共享层**，即本模块的 generation 门。
--
-- 生命周期归宿主意味着：焦点门控、commit 语义、事件订阅全部留在调用方，本模块
-- 既不 require 插件，也不碰事件循环。
--
-- 三个 closure 注入点：
--   * source(req)  → FloatPreview.Content|nil：把 req 解析成"要展示什么"。缺省
--                    实现是只读 scratch 文件预览管线（见 default_source）。返回
--                    nil ⇒ 不可预览 ⇒ 关闭。
--   * geometry()   → win_config|nil：每次 (重)建都问一次窗口几何；nil ⇒ 空间
--                    不足 ⇒ 关闭。始终由调用方显式提供（不做"侧栏形状"默认几何）。
--   * on_show(buf, self)：每次 (重)建 buffer 后回调，用于绑 buffer-local 键。

local M = {}

-- Size guards：超过任一阈值就整体放弃预览。故意不做"只渲染可见区域"——部分
-- buffer 内容会破坏很多语言的 treesitter 解析。
local PREVIEW_MAX_BYTES = 1024 * 1024
local PREVIEW_MAX_LINES = 30000

-- Cheap-and-correct 二进制检测：头 8KB 内出现 NUL 字节。和 git / grep -I /
-- ripgrep 同一启发式——文本几乎不含 NUL，二进制（可执行文件、图片、压缩包、
-- PDF）几乎都在前几 KB 出现。
--
-- 为什么必须挡：vim.fn.readfile() 读二进制会把 NUL 静默转成行内 '\n'，随后
-- nvim_buf_set_lines 会拒绝（替换串里不允许 '\n'）。
---@param file string
---@return boolean
local function is_binary(file)
	local f = io.open(file, "rb")
	if not f then
		return true -- 读不了 → 抑制预览
	end
	local chunk = f:read(8192)
	f:close()
	return chunk ~= nil and chunk:find("\0", 1, true) ~= nil
end

-- 缺省 source：把文件路径读进一个只读 scratch buffer。
--
-- 故意不用 vim.fn.bufadd(file)：bufadd 会在 buffer 列表留永久条目，但预览应是
-- 短命的——预览 N 个文件会在 :ls 留 N 条，即使 picker 关了也不消。
--
-- 策略：
--   * 文件已在别处加载 → 从那个 buffer 拷行（保留未存盘编辑与既有 filetype）。
--   * 否则 vim.fn.readfile() 读盘 + vim.filetype.match 猜 filetype——不污染
--     buffer 列表。
--
-- modifiable / readonly 是 buffer-local：设在真实文件 buffer 上会连带把用户主窗
-- 里那份也锁死，所以只读预览只能用 scratch。bufhidden = "wipe" 让 scratch 在其
-- 唯一窗口关闭时自毁——无需 keymap 清理记账。
---@param req any 缺省实现里 req 是绝对文件路径
---@return FloatPreview.Content|nil
local function default_source(req)
	local file = req
	if type(file) ~= "string" or file == "" then
		return nil
	end
	local stat = vim.uv.fs_stat(file)
	if not stat or stat.type ~= "file" or stat.size > PREVIEW_MAX_BYTES then
		return nil
	end
	if is_binary(file) then
		return nil
	end

	local source_lines, ft
	local existing = vim.fn.bufnr(file, false) -- false = 不创建
	if existing ~= -1 and vim.api.nvim_buf_is_loaded(existing) then
		source_lines = vim.api.nvim_buf_get_lines(existing, 0, -1, false)
		ft = vim.bo[existing].filetype
		if ft == "" then
			ft = vim.filetype.match({ filename = file }) or ""
		end
	else
		local ok, lines = pcall(vim.fn.readfile, file)
		if not ok or not lines then
			return nil
		end
		source_lines = lines
		ft = vim.filetype.match({ filename = file }) or ""
	end
	if #source_lines > PREVIEW_MAX_LINES then
		return nil
	end

	local buf = vim.api.nvim_create_buf(false, true)
	-- 防御 pcall：即便有上面的二进制护栏，冷门文件（NUL 在 8KB 之后的 UTF-16、
	-- 怪异换行编码）仍可能产出 nvim_buf_set_lines 拒绝的行。干净退出。
	local ok = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, source_lines)
	if not ok then
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
		return nil
	end
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.bo[buf].readonly = true
	-- filetype 放最后：赋值触发 FileType，启动 treesitter 与 ftplugin。
	if ft ~= "" then
		vim.bo[buf].filetype = ft
	end
	return { buf = buf, key = file }
end

---@class FloatPreview.Content
---@field buf integer       要展示的 buffer
---@field key any           身份标识；key 相同且 float 存活 ⇒ 只重定位光标，不重建
---@field cursor? integer[] {row, col}（row 1-based, col 0-based）；展示后置光标并 zz 居中

---@class FloatPreview.Opts
---@field source? fun(req: any): FloatPreview.Content|nil 缺省 = 只读 scratch 文件预览管线
---@field geometry fun(): vim.api.keyset.win_config|nil   每次 (重)建问一次；nil ⇒ 关闭。必填
---@field wo? table<string, any>                          窗口局部选项，随开窗应用
---@field on_show? fun(buf: integer, self: FloatPreview)  每次 (重)建 buffer 后回调
---@field auto? boolean                                   auto-follow 初始状态（默认 false）

---@class FloatPreview
---@field source fun(req: any): FloatPreview.Content|nil
---@field geometry fun(): vim.api.keyset.win_config|nil
---@field wo table<string, any>?
---@field on_show fun(buf: integer, self: FloatPreview)?
---@field auto boolean
---@field private _win integer?  活 float winid
---@field private _buf integer?  当前展示的 bufnr
---@field private _key any       当前展示内容的身份标识
---@field private _gen integer   单调 generation，show/close 各自 bump
---@field private _muted any     一次性 mute 标识（下一个匹配的 show_auto 被吸收）
local FloatPreview = {}
FloatPreview.__index = FloatPreview

---@param opts FloatPreview.Opts
---@return FloatPreview
function M.new(opts)
	assert(type(opts.geometry) == "function", "float_preview: geometry 必填且须为函数")
	return setmetatable({
		source = opts.source or default_source,
		geometry = opts.geometry,
		wo = opts.wo,
		on_show = opts.on_show,
		auto = opts.auto or false,
		_win = nil,
		_buf = nil,
		_key = nil,
		_gen = 0,
		_muted = nil,
	}, FloatPreview)
end

-- generation 单调自增，返回新值。show / close 都 bump——晚到的（旧 generation
-- 的）apply 会被 _apply 丢弃，这是共享层的 stale 竞态防护。
---@private
---@return integer
function FloatPreview:_bump()
	self._gen = self._gen + 1
	return self._gen
end

-- 置光标 + zz 居中，两步都 pcall（cursor 越界 / 窗口刚失效都不该炸）。
---@private
---@param cursor integer[]?
function FloatPreview:_place_cursor(cursor)
	if not cursor or not self:is_open() then
		return
	end
	pcall(vim.api.nvim_win_set_cursor, self._win, cursor)
	pcall(vim.api.nvim_win_call, self._win, function() vim.cmd("normal! zz") end)
end

-- 在 generation 门后应用一份已解析的 content：开窗 / 原地换 buffer / 仅重定位。
-- show/show_auto/toggle 捕获当前 gen、解析 source、再调本方法；对异步 source，
-- 一个晚到的旧 gen 结果会在这里被丢弃（gen ~= self._gen）。
---@private
---@param gen integer     解析发起时捕获的 generation
---@param content FloatPreview.Content|nil
---@return boolean shown
function FloatPreview:_apply(gen, content)
	if gen ~= self._gen then
		return false -- stale：本次解析发起后又有 show/close 抢先，丢弃
	end
	if not content or not content.buf or not vim.api.nvim_buf_is_valid(content.buf) then
		self:close()
		return false
	end

	-- 每次 apply 都问一次几何（廉价算术）；nil ⇒ 空间不足 ⇒ 关闭。放在 dedup
	-- 之前：key 未变时也重查几何，"宽度不足即关"才能在高频 CursorMoved 路径上生效。
	local cfg = self.geometry()
	if not cfg then
		self:close()
		return false
	end

	-- key 去重：相同 key 且 float 存活 ⇒ 不重建，只挪光标（CursorMoved 高频路径
	-- 廉价化）。复用活 buffer 的 source（neominimap）里 key==buf，故 content.buf
	-- 恒等于 self._buf，下面的 orphan 删除永不误伤活 buffer；复制型 source
	-- （缺省 scratch）里 key==path，同 key 会拿到一个全新的冗余 scratch——删掉它
	-- 避免泄漏（去重不能引入泄漏）。
	if self:is_open() and self._key ~= nil and content.key == self._key then
		if content.buf ~= self._buf then
			pcall(vim.api.nvim_buf_delete, content.buf, { force = true })
		end
		self:_place_cursor(content.cursor)
		return true
	end

	if self:is_open() then
		-- 同一个 float 窗，原地换 buffer。旧 scratch 若 bufhidden="wipe" 会在窗口
		-- 不再显示它时自毁。几何保持不变（两个调用方几何都位置稳定，无需 set_config）。
		pcall(vim.api.nvim_win_set_buf, self._win, content.buf)
	else
		self._win = vim.api.nvim_open_win(content.buf, false, cfg)
		if self.wo then
			for k, v in pairs(self.wo) do
				vim.wo[self._win][k] = v
			end
		end
	end
	self._buf = content.buf
	self._key = content.key
	self:_place_cursor(content.cursor)
	if self.on_show then
		self.on_show(content.buf, self)
	end
	return true
end

-- 强制显示：解析 source 并展示。source 返回 nil ⇒ 关闭并返回 false。
---@param req any
---@return boolean shown
function FloatPreview:show(req)
	local gen = self:_bump()
	return self:_apply(gen, self.source(req))
end

-- 受 auto 门控的 show（宿主在 CursorMoved / on_change 里调）。另叠一层一次性
-- mute：commit 后宿主 mute(file)，随后节流回火的 show_auto(file) 被吸收恰好一次。
-- mute 比对 req（缺省 file source 里 req == content.key，但在解析 source 前
-- 短路，不白建一个 scratch）。
---@param req any
---@return boolean shown
function FloatPreview:show_auto(req)
	if self._muted ~= nil then
		local muted = self._muted
		self._muted = nil -- 一次性：无论是否命中，都只挡一个事件
		if req == muted then
			return false
		end
	end
	if not self.auto then
		return false
	end
	return self:show(req)
end

-- `p` / <A-p>：float 在就关，不在就 show（强制，绕过 auto）。
---@param req any
function FloatPreview:toggle(req)
	if self:is_open() then
		self:close()
	else
		self:show(req)
	end
end

-- `P`：翻转 auto-follow；开启时立即按 req 刷一帧。返回新的 auto 状态，宿主据此
-- 发各自的 notify（消息文案是宿主特有的，不进本模块）。
---@param req any
---@return boolean auto 翻转后的状态
function FloatPreview:toggle_auto(req)
	self.auto = not self.auto
	if self.auto then
		self:show(req)
	end
	return self.auto
end

-- 一次性吸收下一个携带该 key 的 show_auto（commit 后的节流回火防护）。
---@param key any
function FloatPreview:mute(key) self._muted = key end

-- 幂等关闭：pcall 守卫的 teardown，二次调用无害。bump generation 使任何在途的
-- 旧 apply 失效。
function FloatPreview:close()
	self:_bump()
	if self._win and vim.api.nvim_win_is_valid(self._win) then
		pcall(vim.api.nvim_win_close, self._win, true)
	end
	self._win = nil
	self._buf = nil
	self._key = nil
end

---@return boolean
function FloatPreview:is_open() return self._win ~= nil and vim.api.nvim_win_is_valid(self._win) end

-- 活 float winid（宿主 commit / focus 用），关闭时为 nil。
---@return integer?
function FloatPreview:win()
	if self:is_open() then
		return self._win
	end
	return nil
end

-- 当前展示内容的身份 key（float 存活时），否则 nil。这是 9 个命令原语之外唯一
-- 的只读访问器：snacks 的 <CR>/l confirm 要比对"float 现在显示的文件"是否等于
-- 光标下的 item.file，才决定是 commit-from-preview 还是走默认 confirm。
---@return any
function FloatPreview:key()
	if self:is_open() then
		return self._key
	end
	return nil
end

-- 滚动 float（两个调用方都要）。"down" → <C-d>，"up" → <C-u>。
---@param dir "down"|"up"
function FloatPreview:scroll(dir)
	if not self:is_open() then
		return
	end
	local key = dir == "down" and "<C-d>" or "<C-u>"
	local termcode = vim.api.nvim_replace_termcodes(key, true, false, true)
	vim.api.nvim_win_call(self._win, function() vim.cmd("normal! " .. termcode) end)
end

return M
