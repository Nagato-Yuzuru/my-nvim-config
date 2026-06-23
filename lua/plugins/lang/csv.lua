---
--- csvview.nvim — CSV/TSV/PSV 每列轮转配色(真·彩虹 CSV)+ 列对齐成表格
--- 入口: 打开 csv/tsv/psv 自动开启;:CsvViewToggle 切换;buffer-local <localleader>v 切换
---        (文件限定查看器约定,同 videre/Obsidian/LeetCode)
--- 列配色用 CsvViewCol0..8 高亮组(display_mode="highlight")。
--- 对齐: 数字列右对齐、文本列左对齐(csvview 内置,硬编码不可关)——这正是
---        想要的“数字对齐”;副作用是表头与数字左缘不齐,属预期表格排版。
--- 注意: csv 的高亮由本插件接管;treesitter 的 csv 类型配色会和它抢 extmark
---        优先级,故 lua/plugins/treesitter.lua 的高亮 autocmd 跳过 csv/tsv/psv。
--- parity: nvim-only —— JetBrains 侧用 mechatroner 的 Rainbow CSV 插件实现等价能力,
---         属“视图/工具”单边存在,不镜像到 .ideavimrc。
---
return {
	"hat0uma/csvview.nvim",
	ft = { "csv", "tsv", "psv" },
	cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
	opts = {
		view = { display_mode = "highlight" }, -- 每列上色;"border" 则画分隔线
	},
	config = function(_, opts)
		local csvview = require("csvview")
		csvview.setup(opts)
		-- csvview 不自带“按 ft 自动开”,补一个 autocmd 让打开即见彩虹分列。
		local grp = vim.api.nvim_create_augroup("UserCsvView", { clear = true })
		vim.api.nvim_create_autocmd("FileType", {
			group = grp,
			pattern = { "csv", "tsv", "psv" },
			callback = function(ev)
				csvview.enable(ev.buf)
				vim.keymap.set(
					"n",
					"<localleader>v",
					"<cmd>CsvViewToggle<cr>",
					{ buffer = ev.buf, desc = "CSV: toggle rainbow/align view" }
				)
			end,
		})
		-- ft 懒加载会先触发当前 buffer 的 FileType 再跑 config,上面 autocmd
		-- 抓不到这个触发 buffer,这里对它补开一次。
		local b = vim.api.nvim_get_current_buf()
		if vim.tbl_contains({ "csv", "tsv", "psv" }, vim.bo[b].filetype) then
			csvview.enable(b)
		end
	end,
}
