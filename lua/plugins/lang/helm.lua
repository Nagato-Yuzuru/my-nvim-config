-- towolf/vim-helm 负责把 Helm chart 下的模板识别为 `helm` filetype：
--   - templates/*.yaml / *.tpl  → filetype=helm
--   - Chart.yaml / values.yaml  → 保持 filetype=yaml，归 yamlls 管
-- helm_ls 只挂 `helm` filetype（见 lsp/helm_ls.lua），
-- 所以纯 YAML 仍走 yamlls + SchemaStore，模板走 helm_ls。
-- 注意：不能用 `ft = "helm"` 懒加载——ftdetect 规则本身由这个插件提供，
-- 没有它 Neovim 永远判不出 `helm`。VeryLazy 又太晚（启动时打开的 buffer
-- 已经过完 BufRead，filetype 已定）。用 BufReadPre/BufNewFile 保证规则
-- 在任何文件被读入前就注册进去；插件本体只有 ftdetect/ftplugin，开销
-- 可忽略。
return {
	"towolf/vim-helm",
	event = { "BufReadPre", "BufNewFile" },
}
