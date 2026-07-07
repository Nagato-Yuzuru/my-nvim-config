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
--- 引用方:lua/plugins/lang/markdown.lua(,mr/,mR 联动)、
---         lua/plugins/ui/snacks.lua(,ii 开关 / ,it inline-float 切换)。
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

return M
