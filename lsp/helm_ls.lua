-- helm_ls 需要 `helm` filetype（由 towolf/vim-helm 识别 templates/*.yaml
-- 里的 Go template 语法）。yamlls 不挂 helm filetype，二者不会互相干扰。
return {
	cmd = { "helm_ls", "serve" },
	filetypes = { "helm" },
	root_markers = { "Chart.yaml", ".git" },
}
