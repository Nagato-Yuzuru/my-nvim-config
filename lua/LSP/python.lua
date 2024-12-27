-- ./lua/LSP/python.lua
local lspconfig = require('lspconfig')

-- 配置 Pyright 作为 Python 的 LSP 服务器
lspconfig.pyright.setup({
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "basic",  -- 可选： "off", "basic", "strict"
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
      },
    },
  },
  on_attach = function(client, bufnr)
    -- 你可以在这里添加自定义的 LSP 配置，比如快捷键绑定等
    print("Python LSP started.")
  end,
})

