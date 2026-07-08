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
-- 多选：telescope（`<Tab>` 多选）。本文件是这份配置里 telescope 的唯一消费者
-- （picker 全局是 Snacks，见 marks.lua 的 picker_backend 注释）；不装它会
-- 回退到单选的 vim.ui.select，多选模版就没法一次凑齐了。
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
				-- generate(opts) 读 opts.args 当目标路径；裸字符串会被当 opts 表索引、
				-- 参数静默丢失（等于写相对路径 .gitignore），所以必须包成表。
				function() require("gitignore").generate({ args = vim.fn.getcwd() }) end,
				desc = "Git: generate .gitignore (templates)",
			},
		},
	},
}
