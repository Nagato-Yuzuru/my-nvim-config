-- awk-language-server（Beaglefoot，npm，mason 包 awk-language-server）。ft 是
-- nvim 内置的 awk（*.awk）；parser 在 plugins/treesitter.lua。同 jq：语言面无
-- 事实可注册，无 plugins/lang/awk.lua。
return {
	cmd = { "awk-language-server" },
	filetypes = { "awk" },
	root_markers = { ".git" },
}
