-- ./lua/LSP/go.lua
local lspconfig = require('lspconfig')

-- 配置 gopls 作为 Go 的 LSP 服务器
lspconfig.gopls.setup({
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
        shadow = true,
      },
      staticcheck = true,
    },
  },
  on_attach = function(client, bufnr)
    -- 你可以在这里添加自定义的 LSP 配置，比如快捷键绑定等
    print("Go LSP started.")
  end,
})

