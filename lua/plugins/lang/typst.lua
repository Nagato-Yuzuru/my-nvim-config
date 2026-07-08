-- Typst WYSIWYG：typst-preview.nvim
--
-- 与 markdown 那边 render-markdown.nvim 的"in-buffer 渲染"不同，typst 没有
-- 在 buffer 里拼出排版的现成方案——内容是真排版（字体 / 数学 / 图片），所以
-- 只能 out-of-buffer：tinymist 把 .typ 实时编译成 SVG，浏览器里以 PDF-like
-- 形式渲染并跟随光标。这是目前 typst 生态最接近"所见即所得"的方案。
--
-- Backend 共享 mason 装的 tinymist 二进制（见 lsp/tinymist.lua），不再单独
-- 装第二份预览后端。
return {
	{
		"chomosuke/typst-preview.nvim",
		ft = "typst",
		build = function()
			-- 同步预览前端资源（首次启动时拉一次）；失败要出声，否则 build 报成功
			-- 而预览悄悄坏掉
			local ok, err = pcall(function() require("typst-preview").update() end)
			if not ok then
				vim.notify("typst-preview: 前端资源同步失败: " .. tostring(err), vim.log.levels.WARN)
			end
		end,
		opts = {
			dependencies_bin = { ["tinymist"] = "tinymist" },
			-- nil → 平台默认（macOS open / Linux xdg-open）；浏览器新 tab 打开
			open_cmd = nil,
			-- 编辑器光标移动时，预览同步滚动；CursorHold 触发，不抖
			follow_cursor = true,
			-- 跟随 nvim 背景反转预览底色（深色主题下舒服一点）
			invert_colors = "auto",
		},
		keys = {
			{ "<localleader>tp", "<cmd>TypstPreview<cr>", ft = "typst", desc = "Typst: Preview (browser)" },
			{ "<localleader>tt", "<cmd>TypstPreviewToggle<cr>", ft = "typst", desc = "Typst: Preview toggle" },
			{ "<localleader>tP", "<cmd>TypstPreviewStop<cr>", ft = "typst", desc = "Typst: Preview stop" },
			{
				"<localleader>ts",
				"<cmd>TypstPreviewSyncCursor<cr>",
				ft = "typst",
				desc = "Typst: Sync cursor → preview",
			},
			{
				"<localleader>tF",
				"<cmd>TypstPreviewFollowCursorToggle<cr>",
				ft = "typst",
				desc = "Typst: Toggle follow cursor",
			},
		},
	},
}
