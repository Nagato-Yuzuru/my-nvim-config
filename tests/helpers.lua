-- tests/test_*.lua 的公共积木：child 工厂 + 每 case 全新重启的标准 hooks。
-- require("tests.helpers") 依赖 cwd = repo 根（lua 默认 package.path 含
-- "./?.lua"）——测试本来就约定从 repo 根启动，见 minimal_init.lua 头注释。

local H = {}

H.root = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")))
H.minimal_init = H.root .. "/tests/minimal_init.lua"

---新建 child 及配套 hooks：每个 case 前重启（进程级隔离，状态不可能跨 case
---泄漏），套件结束后停掉。用法：
---  local child, hooks = H.new_child()
---  local T = MiniTest.new_set({ hooks = hooks })
---@return table child
---@return table hooks
function H.new_child()
	local child = MiniTest.new_child_neovim()
	local hooks = {
		pre_case = function() child.restart({ "-u", H.minimal_init }) end,
		post_once = child.stop,
	}
	return child, hooks
end

return H
