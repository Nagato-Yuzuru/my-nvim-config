-- 上游 2025 年 archived、2026-04 宣布复活（#178），Mason 升级时复查维护状态。
--
-- 子目录的 meson.build 不是项目根（subdir() 链从顶层起解析），故不作 marker；
-- 顶层特有的 meson.options（旧名 meson_options.txt）优先，退回 .git。
return {
	cmd = { "mesonlsp", "--lsp" },
	filetypes = { "meson" },
	root_markers = { { "meson.options", "meson_options.txt" }, ".git" },
}
