-- screenkey.nvim：把按下的键实时画在右下角浮窗里，用来给自家插件
-- （lua/plugins/edit/bang.lua = bang.nvim）录教程 / 演示。
--
-- 为什么用 nvim 内的插件，而不是 KeyCastr 这类系统级键位显示器：录制走 VHS
-- （charmbracelet/vhs，bang.nvim 仓库里已有 bang.tape），VHS 只截终端内容。浮窗
-- 是终端单元格，会被录进去；系统覆盖层画在终端窗口之外，不会。
--
-- 只调两个默认值：
--   group_mappings  把构成同一个映射的按键并成一组显示（g! 显示成 g!，不是 g
--                   加 !）——教 operator 类插件时这才是想看的粒度。
--   clear_after     默认 3s 短于 tape 里常见的 Sleep，键位会在观众读完前消失。
return {
	{
		"NStefan002/screenkey.nvim",
		version = "*",
		cmd = "Screenkey",
		keys = {
			{ "<leader>vk", "<cmd>Screenkey toggle<cr>", desc = "Toggle screencast keys" },
		},
		opts = {
			group_mappings = true,
			clear_after = 5,
		},
	},
}
