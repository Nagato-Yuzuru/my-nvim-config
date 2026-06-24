-- IDEA 风「裸标识符自动补全 + 自动 import」的 Go 实现（nvim-only：JetBrains/GoLand
-- 原生有此能力，用它自己的全工程符号索引；gopls **不做**裸标识符未导入补全——
-- 输入裸 `Builder` 得不到 `strings.Builder`，那是 golang/go#58291，性能原因长期不实现）。
--
-- go-deep 的填法：一份**独立于 gopls** 的 stdlib 符号索引（开机构建，覆盖**整个**标准库、
-- 不要求已 import）+ gopls `workspace/symbol`（本 module 的包 + 已加载的第三方依赖）。
-- 输入 `Builder` 模糊命中 `strings.Builder`，接受时插入**限定形式** `strings.Builder`，
-- 并用 treesitter 补 `import "strings"`。第三方未加载的包受 gopls workspace/symbol 范围
-- 限制（#53004），覆盖不如 stdlib 完整——这是上游约束，非配置项。
--
-- 后端是一个 plugin-local 的 Go 二进制，由 build 步骤用**仓库内 vendored 源码**本地
-- `go build`（离线，**不**下载预编译二进制、不走 GOPATH/PATH）。需要 Go 1.25+（本机 1.26）。
-- 安全审计基于 commit a1d229e / backend v0.0.16。**注意：这里跟 `master` 分支(未 pin)**,
-- 所以 `:Lazy update` 会拉新代码并自动 `go build` 编译——**每次 update 后都应重审**那次
-- diff(build 会编译检出的任意源码)。想锁定可改回 `commit = "<sha>"`。
--
-- 配置 SSOT 是 `vim.g.go_deep`（后端启动 + 各请求默认值）；blink 端的 provider 注册在
-- lua/plugins/completion/blink.lua（`sources.per_filetype.go` + `sources.providers.go_deep`）。
return {
	{
		"samiulsami/go-deep.nvim",
		ft = "go", -- Go-only：打开 go 文件即载入，先于首次补全；blink provider 届时可 require
		branch = "master",
		build = ':lua require("go_deep").build()', -- 安装/更新时离线编译后端 + 预建 stdlib 索引
		config = function()
			-- 上游 bug 兜底（commit a1d229e）：无 import 的 go 文件里 get_imported_paths 返回
			-- `{}`，Neovim msgpack 把空表编码成空**数组**,而后端把 imported_paths 解码成
			-- map[string]string → "cannot convert ArrayLen to map[string]string",**后端整个
			-- 崩退**(code 1)。这恰好命中"空文件 / 加第一个 import"这一最常见场景。用
			-- vim.empty_dict() 强制空表编码为 map。client.lua 通过 `treesitter.get_imported_paths`
			-- 字段访问调用,故 mutate 模块字段即可生效。升级重审时复查此 wrap 是否仍需要。
			local ts = require("go_deep.treesitter")
			local orig_get = ts.get_imported_paths
			ts.get_imported_paths = function(bufnr)
				local r = orig_get(bufnr)
				if type(r) == "table" and next(r) == nil then
					return vim.empty_dict()
				end
				return r
			end

			-- 没有 setup()：配置就是这个全局表（resolve_config 每次请求读它）。
			vim.g.go_deep = {
				notifications = true,
				index = true, -- 持久化 stdlib 索引（≤1MB）：裸标识符补全的核心来源
				workspace_symbols = true, -- 非 stdlib（本 module + 已加载第三方）走 gopls workspace/symbol
				workspace_timeout = 15,
				completion_cache = true,
				min_keyword_length = 3, -- IDEA 同款 3 字符起；嫌噪/怕 >100 panic 可调 4
				max_items = 30,
				max_from_same_package = 4,
				exclude_imported_packages = true, -- 已 import 的包交给原生 gopls LSP 源，避免重复项
				exclude_vendored_packages = false,
				exclude_internal_packages = true,
				exclude_test_files = true,
			}
		end,
	},
}
