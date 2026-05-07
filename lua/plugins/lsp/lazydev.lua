-- lazydev.nvim — 让 lua_ls 看到 lazy.nvim 装的第三方插件类型。
--
-- 没有它的话，lua_ls 的 workspace 只看你项目内的 Lua 文件；插件源在
-- ~/.local/share/nvim/lazy/<plugin>/lua/ 下，对 lua_ls 不可见。结果就是
-- 写到 `---@param picker snacks.Picker` 这种第三方类型注解时，lua_ls 报
-- "Undefined type or alias snacks.Picker"，并且 `picker:cwd()` 之类的方法
-- 调用全部跳出 `Undefined field` 警告。
--
-- 为什么 lazydev 比直接配 `workspace.library = { vim.fn.stdpath("data") ..
-- "/lazy" }` 强：
--   1. 按需加载——只有当代码里 `require("snacks.X")` 或注解里出现
--      `snacks.*` 时才把 snacks.nvim 的 lua/ 加进 workspace，启动期不
--      索引你不依赖的插件。
--   2. 标记为 third-party——lua_ls 把这部分视为只读 library，不会把它
--      当成你项目的源代码报"unused function"等噪音。
--   3. 比手维护一份 library 路径列表更不易漂移——加新插件依赖时，只要
--      在 words / library 里点一下，路径用插件名而不是绝对路径。
--
-- words 字段：当代码里出现这些词（全局或类型名），就把对应 library 加
-- 进 workspace。snacks 把全局 `Snacks` 注入运行时，所以 words = { "Snacks" }
-- 能让 lua_ls 在看到该词时主动拉 snacks 的类型定义；用法注解里直接写
-- `snacks.Picker` 也能命中（lazydev 默认还会按 `require()` 字符串匹配）。
return {
	"folke/lazydev.nvim",
	ft = "lua",
	opts = {
		library = {
			-- snacks 是 ui/snacks.lua 直接打类型注解的依赖。
			{ path = "snacks.nvim", words = { "Snacks" } },
			-- nvim 自身的 vim.uv / vim.lsp / vim.diagnostic 等运行时类型；
			-- lazydev 内置识别，写 path = "luvit-meta/library" 是社区惯例。
			{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
		},
	},
}
