-- ? = 交互输入任意多字符定界符（add / find / delete 全支持）
-- 输入单串 → 左右相同；含空格则按首个空格拆成 "L R"
-- 例：ys iw ? -> """    cs ? ? -> 旧/新各提示一次    ds ? -> 提示要删的串
local function split(s)
	local sp = s:find(" ")
	if sp then
		return s:sub(1, sp - 1), s:sub(sp + 1)
	end
	return s, s
end

-- find→delete 在同一次操作里共享一次提示
local pending ---@type {left:string,right:string}|nil

local function prompt(label)
	local s = vim.fn.input(label)
	if s == "" then
		return nil
	end
	local l, r = split(s)
	if l == "" or r == "" then
		vim.notify("surround: empty delimiter", vim.log.levels.WARN)
		return nil
	end
	return { left = l, right = r }
end

-- 同一次 ds/cs 内 find→delete 共享提示；下个事件循环自动失效，
-- 防止 find 找不到匹配时 pending 残留被下次操作复用。
local function ensure_pending()
	if not pending then
		pending = prompt("Surround (find): ")
		if pending then
			vim.schedule(function() pending = nil end)
		end
	end
	return pending
end

return {
	{
		"kylechui/nvim-surround",
		version = "*",
		event = "VeryLazy",
		opts = {
			aliases = { ["<"] = "t" },
			surrounds = {
				["?"] = {
					add = function()
						local p = prompt("Surround: ")
						if not p then
							return nil
						end
						return { { p.left }, { p.right } }
					end,
					find = function()
						local p = ensure_pending()
						if not p then
							return nil
						end
						local pat = vim.pesc(p.left) .. ".-" .. vim.pesc(p.right)
						return require("nvim-surround.config").get_selection({ pattern = pat })
					end,
					delete = function()
						local p = ensure_pending()
						pending = nil
						if not p then
							return nil
						end
						local pat = "^(" .. vim.pesc(p.left) .. ")().-(" .. vim.pesc(p.right) .. ")()$"
						return require("nvim-surround.config").get_selections({ char = "?", pattern = pat })
					end,
				},
			},
		},
	},
}
