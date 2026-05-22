-- chezmoi.vim：编辑器内的 filetype detection + 模板高亮。
--   - dot_zshrc.tmpl / private_dot_ssh/config.tmpl 类前缀文件名 → 解码回宿主 ft
--     （zsh / sshconfig …）
--   - 在宿主语法上叠加 Go template 高亮，看得清 `{{ .chezmoi.os }}` 之类表达式

return {
	{
		"alker0/chezmoi.vim",
		-- 必须 lazy=false（README FAQ-2）。用 event="BufReadPre" 会形成死锁：
		-- 加载发生在 BufReadPre 触发的当下，此时插件自己的 BufReadPre 自动
		-- 命令还没注册，对**这个**触发它加载的 buffer 不生效。
		-- use_tmp_buffer 让插件不依赖加载顺序，但前提是它自己已经 registered。
		lazy = false,
		init = function()
			-- README FAQ-2 推荐 lazy.nvim 必开：通过临时 buffer 跑 builtin
			-- ftdetect，绕开 `setfiletype` 每 buffer 只能调一次的限制。
			vim.g["chezmoi#use_tmp_buffer"] = true
		end,
	},
}
