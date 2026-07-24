-- PromQL language server（prometheus-community/promql-langserver）。
--
-- 裸 stdio LSP：不传 --config-file 也能跑——离线即有语法诊断、类型/函数文档、函数
-- ＆静态指标名补全、签名提示。接 Prometheus 实例才多出 label 值补全 + 指标 help
-- 字符串（离线能力不受影响）。
--
-- 打开“连后端” = 给它一个 Prometheus URL，三选一（都作用于下面这个裸 cmd）：
--   1. env `LANGSERVER_PROMETHEUSURL=http://localhost:9090` —— **首选**，零代码：
--      cmd 继承 nvim 环境即生效；per-project 用 direnv / mise.toml 设最干净，URL
--      不落进这份共享配置（envconfig 前缀 LANGSERVER + 字段 PrometheusURL）。
--   2. `--config-file <yaml>`（内含 `prometheus_url:`）——加进下面的 cmd。
--   3. LSP didChangeConfiguration 推 `{ promql = { url = "..." } }`——写进 settings。
--
-- 只挂 promql filetype（独立 .promql 文件）：**不**挂 yaml——LSP 会把整份 yaml 当
-- PromQL 解析而全线报错。yaml 规则文件里的 PromQL 走 treesitter 注入高亮
-- （queries/yaml/injections.scm）+ pint lint（plugins/lint/nvim-lint.lua），不靠这个
-- LSP。
--
-- 不在 mason（Go 二进制，go install），故不进 tools/mason_ensure.lua 的 LSP_TOOLS；
-- 由 core/lsp.lua 按 tools/promql_toolchain.is_installed() 探测后 enable，散文件
-- root/cwd 安全默认由 tools/lsp_root 统一注入（同 scheme/swift/tsc 的处理）。
return {
	cmd = { "promql-langserver" },
	filetypes = { "promql" },
}
