-- Embedded-language 区块背景着色。
--
-- 触发源：treesitter language injection（包括 `# language=<x>` 这类标记，
-- 见 queries/{python,lua,yaml}/injections.scm；也覆盖 markdown 代码块、
-- vue/svelte SFC 等任何被 injection 处理出子语言树的场景）。
--
-- 实现走 LanguageTree:children() + included_regions() 直接拿子语言区间，
-- 不重跑 injection query，避免和 treesitter 的解析重复。
--
-- 颜色：tokyonight moon 下取 #2e2920（低饱和暖灰）。反向选 hue 是有意为之——
-- moon 整体冷蓝紫，embed 区用暖色形成色温对比，比同色系再深一档更容易识别。
-- 低饱和 + 压暗 → 不会和 DiagnosticVirtualTextWarn 的黄读串，也不抢 Visual /
-- Search 等冷色 hl。换主题时在 on_highlights 里覆盖 EmbedBackground 即可。
--
-- priority = 99：低于 treesitter 默认 100，所以只染背景、不抢前景颜色。

local M = {}

local HL_GROUP = "EmbedBackground"
local PRIORITY = 99

local ns = vim.api.nvim_create_namespace("embed_bg")
local augroup = vim.api.nvim_create_augroup("UserEmbedBackground", { clear = true })

local function refresh(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then return end
	-- 只处理普通文件 buffer，跳过 terminal / picker / 浮窗工具 buffer
	if vim.bo[bufnr].buftype ~= "" then return end

	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not ok or not parser then return end

	parser:parse(true)
	for _, child in pairs(parser:children()) do
		for _, region in ipairs(child:included_regions()) do
			for _, r in ipairs(region) do
				-- r = { srow, scol, sbyte, erow, ecol, ebyte }
				vim.hl.range(
					bufnr,
					ns,
					HL_GROUP,
					{ r[1], r[2] },
					{ r[4], r[5] },
					{ priority = PRIORITY, inclusive = false }
				)
			end
		end
	end
end

-- 简易 per-buffer debounce：TextChanged 期间高频触发会拖慢编辑响应。
local timers = {}
local function schedule_refresh(bufnr, delay)
	local t = timers[bufnr]
	if t then
		t:stop()
		t:close()
	end
	t = vim.uv.new_timer()
	timers[bufnr] = t
	t:start(delay or 80, 0, vim.schedule_wrap(function()
		if timers[bufnr] == t then
			t:stop()
			t:close()
			timers[bufnr] = nil
		end
		refresh(bufnr)
	end))
end

function M.setup()
	vim.api.nvim_set_hl(0, HL_GROUP, { default = true, bg = "#2e2920" })

	-- 主题切换时 default = true 不会自动重应用（如果新主题里没定义同名组）。
	-- ColorScheme 后重申一次。
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = augroup,
		callback = function()
			vim.api.nvim_set_hl(0, HL_GROUP, { default = true, bg = "#2e2920" })
		end,
	})

	vim.api.nvim_create_autocmd({ "BufWinEnter", "BufReadPost" }, {
		group = augroup,
		callback = function(args) refresh(args.buf) end,
	})

	vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
		group = augroup,
		callback = function(args) schedule_refresh(args.buf, 80) end,
	})

	vim.api.nvim_create_autocmd("BufWipeout", {
		group = augroup,
		callback = function(args)
			local t = timers[args.buf]
			if t then
				t:stop()
				t:close()
				timers[args.buf] = nil
			end
		end,
	})
end

return M
