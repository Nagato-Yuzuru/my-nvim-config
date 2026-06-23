-- 生成 .gitignore：从打包的离线模版里多选语言/框架/工具，一键写入 cwd。
-- 对标 JetBrains 的 `.ignore` 插件最常用的那个动作（选模版生成 .gitignore）。
--
-- 键位：`<localleader>gi`，落在 `<localleader>g` "Git" 组——.gitignore 是 git
-- 配套文件，归 Git 组比归 `<leader>g` "Generate" 更贴切（后者 `gi` 易读成
-- "generate interface"）。
--
-- 行为：默认 *追加* 到已有 .gitignore（不覆盖、不自动保存，避免丢数据）；
-- 需要整文件覆盖用 `:Gitignore!`。
--
-- 多选：telescope（`<Tab>` 多选）。telescope 在本配置里由
-- lua/plugins/edit/marks.lua 引入并常驻，这里仍显式声明为依赖，确保 cmd/keys
-- 懒加载触发时 telescope 已就绪（否则会回退到单选的 vim.ui.select）。
--
-- parity：IDEA 侧已有 hsz 的 `.ignore` 插件，且这是插件 UI、无对应 IDE Action，
-- 故不镜像到 .ideavimrc。
return {
	{
		"wintermute-cell/gitignore.nvim",
		dependencies = { "nvim-telescope/telescope.nvim" },
		cmd = "Gitignore",
		keys = {
			{
				"<localleader>gi",
				function() require("gitignore").generate(vim.fn.getcwd()) end,
				desc = "Git: generate .gitignore (templates)",
			},
		},
	},
}
