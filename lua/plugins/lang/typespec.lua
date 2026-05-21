-- TypeSpec：没有需要安装的 nvim 插件（LSP 走原生 vim.lsp.enable，formatter 走
-- conform 内的自定义 spec），只需把 .tsp 扩展登记为 ft=typespec —— 否则
-- lsp/tsp_server.lua 里 filetypes = { "typespec" } 永远不匹配，server 不启。
-- 没有 tree-sitter grammar：nvim-treesitter main 分支的 parser 集里没有 typespec
-- （社区 happenslol/tree-sitter-typespec 不在官方列表，query 文件也得自维护）。
-- 语义高亮靠 LSP semantic tokens 顶，等官方收录再补 TS。

vim.filetype.add({ extension = { tsp = "typespec" } })

return {}
