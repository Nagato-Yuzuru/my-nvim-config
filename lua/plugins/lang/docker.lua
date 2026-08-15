-- 语言域：Docker —— 复合 ft detection（无插件）。
-- dockerls / hadolint 的安装归 install plane（mason_ensure.lua）。
require("tools.lang_registry").register("docker", {
	ft = {
		pattern = {
			["docker%-compose%.ya?ml"] = "yaml.docker-compose",
			["%.?[Dd]ockerfile%..+"] = "dockerfile",
		},
	},
})

return {}
