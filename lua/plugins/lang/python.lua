-- 语言域：Python。LSP 由 tools/mason_ensure.lua 的 LSP_TOOLS 启用，不经 lang_registry。

-- :PyVersion [3.10|py310] 覆盖 ruff / ty 的版本，! 清除；见 tools/python_version.lua。
vim.api.nvim_create_user_command("PyVersion", function(opts)
	local pv = require("tools.python_version")
	local arg = vim.trim(opts.args)
	if not opts.bang and arg == "" then
		local v = pv.get()
		vim.notify(
			v and ("[python] ruff/ty version override: " .. v)
				or "[python] no override — ruff/ty follow project config. Usage: :PyVersion 3.10 | :PyVersion!",
			vim.log.levels.INFO
		)
		return
	end
	local v
	if not opts.bang then
		local err
		v, err = pv.normalize(arg)
		if not v then
			vim.notify("[python] " .. err, vim.log.levels.ERROR)
			return
		end
	end
	pv.set(v)
	local restarted = pv.restart()
	local what = v and ("override set to " .. v) or "override cleared"
	local tail = #restarted > 0 and ("; restarted " .. table.concat(restarted, ", "))
		or "; applies when ruff/ty next start"
	vim.notify("[python] " .. what .. tail, vim.log.levels.INFO)
end, {
	nargs = "?",
	bang = true,
	desc = "Override Python version for ruff/ty (session-only); ! clears",
	complete = function(lead)
		return vim.tbl_filter(
			function(v) return vim.startswith(v, lead) end,
			require("tools.python_version").supported()
		)
	end,
})

return {}
