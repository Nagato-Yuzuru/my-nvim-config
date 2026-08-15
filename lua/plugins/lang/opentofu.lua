-- 语言域：OpenTofu / Terraform —— ft 归并（无插件）。
-- OpenTofu 独有扩展名归到 terraform 系 ft，复用同一套 treesitter parser /
-- tofu-ls / tofu_fmt（.tofu 同名时覆盖 .tf，见 OpenTofu 文档）。
-- tofu-ls / tflint 的安装与 OpenTofu-first 的 why 见 install plane（mason_ensure.lua）。
require("tools.lang_registry").register("opentofu", {
	ft = {
		extension = {
			tfvars = "terraform-vars",
			tofu = "terraform",
			tofuvars = "terraform-vars",
		},
	},
})

return {}
