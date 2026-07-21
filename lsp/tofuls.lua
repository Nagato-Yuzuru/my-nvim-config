-- OpenTofu language server (tofu-ls，terraform-ls 的 fork)。
-- filetypes 用 terraform/terraform-vars：本仓库把 .tf/.tofu 归到 terraform、
-- .tfvars/.tofuvars 归到 terraform-vars（见 core/options.lua 的 vim.filetype.add），
-- tofu-ls 官方接受这两个作为 opentofu/opentofu-vars 的 language-id 别名。
-- experimentalFeatures 与 terraform-ls 同构（tofu-ls docs/SETTINGS.md）：
--   validateOnSave      —— 保存时在文件所在目录跑 `tofu validate`
--   prefillRequiredFields —— provider/resource/data 块补全时预填必填字段
return {
	cmd = { "tofu-ls", "serve" },
	filetypes = { "terraform", "terraform-vars" },
	root_markers = { ".terraform", ".git" },
	init_options = {
		experimentalFeatures = {
			validateOnSave = true,
			prefillRequiredFields = true,
		},
	},
}
