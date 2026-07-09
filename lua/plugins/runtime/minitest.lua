-- mini.test：本仓自有逻辑（lua/tools/* 等）的测试框架。测试在 tests/test_*.lua，
-- 每个 case 跑在 `-u tests/minimal_init.lua` 的 child 实例里，不依赖本配置。
--
-- 这份 spec 只提供交互式入口——改代码时就地跑当前文件/光标下用例：
--   :lua require("mini.test"); MiniTest.run_file()      当前文件
--   :lua require("mini.test"); MiniTest.run_at_location()  光标下 case
-- （require 触发 lazy 的模块级加载 + setup。）完整跑法与 CI 同一条命令，
-- 见 tests/minimal_init.lua 头注释。门禁在 CI（.github/workflows/test.yml），
-- 本地不挂 hook。
return {
	{
		"nvim-mini/mini.test",
		version = false,
		lazy = true, -- require("mini.test") 即加载（lazy.nvim 的模块级懒加载）
		opts = {},
	},
}
