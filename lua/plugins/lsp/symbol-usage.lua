-- symbol-usage: 在符号上方显示"N usages, M impls"虚拟文本——对位 JetBrains 默认
-- 开启的 Code Vision (usages + implementations)。nvim 侧补齐 IDE 已有的能力，
-- 方向是消除非对称，.ideavimrc 不需要注释。Code Vision 的第三项 code author
-- 由 gitsigns current_line_blame 承担（git/gitsigns.lua）。
--
-- 插件的第三个计数器 definition（textDocument/definition 返回的位置数）故意不开：
-- 它与接口关系无关，正常代码永远是 1，只有 TS 重载/声明合并、lua_ls 多处赋值
-- 这类情况才 >1，IDEA 也没有对应项。
--
-- 为什么不是原生 codelens（core/lsp.lua 已开 vim.lsp.codelens.enable）：
-- 引用计数 lens 由服务端决定给不给——gopls 只有 generate/test/tidy 一类命令型
-- lens，clangd 没有，lua_ls / rust-analyzer 有但默认关且显示风格各异。本插件在
-- 客户端做：documentSymbol 拿符号列表，再逐个发 textDocument/references 计数，
-- 所以只要服务端会答 references 就统一生效。
--
-- implementations 同理走 textDocument/implementation，插件会先查服务端的
-- implementationProvider，lua_ls / ty 这类没有的直接跳过。只对接口/类型/方法发
-- （IMPL_KINDS），普通函数不发——请求量才不会整体翻倍。数字的含义由服务端定：
-- 接口上是实现者数；gopls 对具体类型和它的方法返回**它满足的接口**，所以 struct
-- 上的 "N impls" 读作"实现了 N 个接口"——这正是 IDEA gutter 实现箭头的反向信息。
-- 0 不显示（IDEA 同样只在有实现时显示），否则每个无接口的方法都会挂一条噪音。
--
-- 与 codelens 不重复显示：lua_ls 的 Lua.codeLens.enable 默认 false，无引用计数。
-- rustaceanvim 默认 lens 有 run/debug/implementations——implementations 与本插件
-- 重叠，rust 由 filetypes 覆盖关掉本插件的 implementation，保留 rust-analyzer 的
-- lens（它按 impl 块计数，语义比 LSP implementation 请求更贴 Rust）。
--
-- 代价：documentSymbol 一次 + 每个符号一次 references（IMPL_KINDS 再加一次
-- implementation），但计数只对**视口内**的符号发（WinScrolled 时补算，视口外先挂
-- "loading..." 占位），所以大文件的开销按屏而不是按文件算。刷新契机：LspAttach /
-- TextChanged / InsertLeave / 滚动 / BufEnter（强制），均有 debounce。实测 gopls /
-- ty / tsc 小文件 ~1s；lua_ls 首次 ~5s 是它索引工作区的时间，不是插件的。
--
-- 懒加载：event = LspAttach。插件在 setup() 里自建 LspAttach autocmd，lazy 加载
-- 后会带 buffer/data 重放同一事件（lazy/core/handler/event.lua nvim_exec_autocmds），
-- 所以触发加载的那个 buffer 也能被 attach 到。
local SymbolKind = vim.lsp.protocol.SymbolKind

-- IDEA 的 Code Vision 对类/接口同样显示 usages：在插件默认的 Function/Method
-- 之外补上这三种，覆盖 Go 的 type、Rust 的 struct/trait、TS 的 class/interface。
local TYPE_KINDS = { SymbolKind.Class, SymbolKind.Struct, SymbolKind.Interface }
-- implementation 只对这些发：类型 + 方法（接口方法 → 实现者；struct 方法 →
-- 满足的接口方法）。Function 不发，见头注释。
local IMPL_KINDS = vim.list_extend({ SymbolKind.Method }, TYPE_KINDS)

-- 插件默认 text_format 的差异只有一处：implementation 为 0 时不显示。
---@param symbol { references?: integer, implementation?: integer, stacked_count: integer }
local function text_format(symbol)
	local parts = {}
	if symbol.references then
		local n = symbol.references
		parts[#parts + 1] = ("%s %s"):format(n == 0 and "no" or n, n == 1 and "usage" or "usages")
	end
	if symbol.implementation and symbol.implementation > 0 then
		local n = symbol.implementation
		parts[#parts + 1] = ("%d %s"):format(n, n == 1 and "impl" or "impls")
	end
	-- 同一行还有别的符号时插件用 " | +N" 提示（它们的计数没地方画）。
	local stacked = symbol.stacked_count > 0 and (" | +%d"):format(symbol.stacked_count) or ""
	return table.concat(parts, ", ") .. stacked
end

return {
	"Wansmer/symbol-usage.nvim",
	event = "LspAttach",
	-- 故意不绑开关键：默认常开，IDEA 的 Code Vision 同样没有快捷键、只在设置里。
	-- 偶尔要关（录屏、终端鼠标选区会把虚拟行选进去）走
	-- `:lua require("symbol-usage").toggle()`，不值得占一个键。
	opts = function()
		-- 插件按 filetype 的覆盖表（langs.lua：lua 过滤匿名函数；JS 系把箭头函数
		-- 变量算进来）会**整个替换** kinds 列表，顶层的 kinds 对这些 ft 不生效。
		-- 从插件自己的表派生，而不是手抄 ft 清单——上游加语言时这里自动跟上。
		local filetypes = {}
		for ft, cfg in pairs(require("symbol-usage.langs")) do
			if cfg.kinds then
				filetypes[ft] = { kinds = vim.list_extend(vim.deepcopy(cfg.kinds), TYPE_KINDS) }
			end
		end
		-- ft 覆盖表与顶层 opts 是深合并，只盖 enabled 即可（见头注释 rustaceanvim 段）。
		filetypes.rust = { implementation = { enabled = false } }
		return {
			kinds = vim.list_extend({ SymbolKind.Function, SymbolKind.Method }, TYPE_KINDS),
			-- 插件支持按方法单独限定 kinds（options.lua 未在类型注解里写，但
			-- worker.lua is_need_count 读 opts[method].kinds）。
			implementation = { enabled = true, kinds = IMPL_KINDS },
			text_format = text_format,
			-- 'above' 与 IDEA 的 Code Vision 位置一致；配合默认的 request_pending_text
			-- 占位，避免请求返回时行跳动。
			vt_position = "above",
			filetypes = filetypes,
		}
	end,
	-- 用 config 而不是纯 opts：setup 之后还要挂一个 autocmd（见下）。
	config = function(_, opts)
		require("symbol-usage").setup(opts)
		-- rust-analyzer 在索引完成前对 references 返回空，插件把空当作 0 记下就不再
		-- 问了（后续只在 BufEnter 强制重算），于是首次打开的计数一直是错的。
		-- 监听它索引结束（token rustAnalyzer/cachePriming，nvim 会把 begin 的
		-- title "Indexing" 带到 end 事件上）对当前 buffer 强制刷新一次；其它
		-- buffer 靠既有的 BufEnter 强制重算兜底。
		vim.api.nvim_create_autocmd("LspProgress", {
			pattern = "end",
			group = vim.api.nvim_create_augroup("symbol_usage_reindex", { clear = true }),
			callback = function(ev)
				if ev.data.params.token ~= "rustAnalyzer/cachePriming" then
					return
				end
				if vim.lsp.buf_is_attached(0, ev.data.client_id) then
					require("symbol-usage").refresh()
				end
			end,
		})
	end,
}
