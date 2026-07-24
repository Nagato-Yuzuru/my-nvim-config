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
-- 由 core/lsp.lua 按 tools/promql_toolchain.is_installed() 探测后 enable。
--
-- root_dir：本文件**不**声明 root_markers——散 .promql 文件没有有意义的项目根，
-- 一律走 single-file 模式。lsp_root.apply_safe_defaults 只包装声明了 root_markers
-- 的 server（见 tools/lsp_root.lua），故 promql_ls 既不拿 root_dir 也不拿
-- cmd_with_safe_cwd 沙箱。这是安全的：那套 cwd 沙箱是给 ruff/ty/lua_ls 这类"无
-- workspace 就爬 cwd"的 server 兜底的，而 promql-langserver 只解析 buffer 内容、
-- 不扫文件系统，从 $HOME 起也不会把家目录树纳入辖区。
return {
	cmd = { "promql-langserver" },
	filetypes = { "promql" },
}
