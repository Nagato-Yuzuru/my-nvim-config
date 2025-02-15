-- ./lua/LSP/yaml.lua
local lspconfig = require('lspconfig')

-- 配置 yaml-language-server 作为 YAML 的 LSP 服务器
lspconfig.yamlls.setup({
  settings = {
    yaml = {
      schemas = {
        -- Kubernetes YAML 文件的 schema
        ["https://raw.githubusercontent.com/instrumenta/kubernetes-json-schema/master/v1.18.0-standalone-strict/all.json"] = "*.k8s.yaml",
        ["https://raw.githubusercontent.com/instrumenta/kubernetes-json-schema/master/v1.20.0-standalone-strict/all.json"] = "*.k8s.yaml",
      },
    },
  },
  on_attach = function(client, bufnr)
    -- 你可以在这里添加自定义的 LSP 配置，比如快捷键绑定等
    print("YAML LSP started.")
  end,
})

