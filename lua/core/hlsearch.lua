-- Auto-nohlsearch：搜索高亮在”不再导航到匹配项”时自动熄灭。
--
-- 机制（vim.on_key，社区通行做法）：只在 normal 模式看键——
--   · n / N / * / # / ? / / / <CR>  → 属于搜索导航，保持（并确保）hlsearch 亮着
--   · 其它任何键                    → 离开了搜索流，关掉 hlsearch
-- 只在 vim.fn.mode() == "n" 时动作，避免干扰 insert / cmdline / operator-pending
-- 里含这些字符的输入。用独立 namespace 便于需要时精确注销。
local M = {}

-- 触发/保持 hlsearch 的按键（已转成内部 termcode 以便和 on_key 的 typed 参数比对）
local search_keys = {}
for _, key in ipairs({ "n", "N", "*", "#", "?", "/", "<CR>" }) do
	search_keys[vim.api.nvim_replace_termcodes(key, true, false, true)] = true
end

function M.setup()
	local ns = vim.api.nvim_create_namespace("core_auto_hlsearch")
	vim.on_key(function(_, typed)
		-- 有些事件（如粘贴）typed 为空，忽略
		if typed == "" or typed == nil then
			return
		end
		if vim.fn.mode() ~= "n" then
			return
		end
		local want_on = search_keys[typed] ~= nil
		if vim.o.hlsearch ~= want_on then
			vim.o.hlsearch = want_on
		end
	end, ns)
end

return M
