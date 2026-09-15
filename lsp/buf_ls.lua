-- Buf LSP（`buf lsp serve`，buf ≥ 1.73 顶层稳定命令；旧 `buf beta lsp` 仍可用）。
-- 一个二进制覆盖 proto 的全部编辑器面：补全 / hover / goto-def / references /
-- rename / symbols / semantic tokens，lint 诊断按 buf.yaml 规则集推送，
-- textDocument/formatting 即 `buf format`。因此 conform / nvim-lint 都**不接**
-- proto：conform 的 format_on_save 走 lsp_fallback，再接内置 buf_lint 只会双份
-- 诊断（同 ty vs pyright 的取舍，见 mason_ensure.lua）。
-- 安装归 LSP_TOOLS（bin "buf" / mason "buf"，带 verify_cmd 识破 mise 未设版本的
-- 空 shim）。.proto → proto 是 nvim 内置 ft，parser 在 plugins/treesitter.lua，
-- 语言面无事实可注册，故无 plugins/lang/proto.lua（同 jq）。
-- buf breaking / generate / curl 不进编辑器，终端或 overseer 跑。
return {
	cmd = { "buf", "lsp", "serve" },
	filetypes = { "proto" },
	-- buf.yaml 是模块/workspace 根（v2 workspace 也只用 buf.yaml）；buf.work.yaml
	-- 是 v1 workspace 的遗留标记；.git 兜底无 buf 配置的裸 proto 目录。
	root_markers = { "buf.yaml", "buf.work.yaml", ".git" },
}
