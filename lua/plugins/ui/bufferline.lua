return {
	{
		"akinsho/bufferline.nvim",
		event = "VeryLazy",
		cond = function() return not vim.g.started_by_firenvim end,
		dependencies = {
			{ "echasnovski/mini.bufremove", version = false }, -- 更靠谱的关缓冲
		},
		opts = {
			options = {
				diagnostics = "nvim_lsp",
				offsets = {
					{ filetype = "snacks_layout_box", text = "Explorer", highlight = "Directory", separator = true },
				},
				separator_style = "slant",
				-- 关闭按钮行为交给 mini.bufremove
				close_command = function(n) require("mini.bufremove").delete(n, false) end,
				right_mouse_command = function(n) require("mini.bufremove").delete(n, false) end,
				-- 当前 tab 若被 <C-x>R 命过名，把名字渲染在 tabline 最右——bufferline
				-- 自带的 1/2 编号 indicator 不支持 per-tab 名称（无公开 API），且
				-- 编号 + <n>gt 已经足够当 picker，这里只补"我现在在哪个 workspace"
				-- 的视觉锚点。
				custom_areas = {
					-- 字段名是 fg/bg/link（参考 bufferline/custom_area.lua），不是
					-- README 那个老例子里的 guifg/guibg。link 让我们直接借用一个
					-- 现成 HL group，省得手动抽 #rrggbb，主题切换时也跟着变。
					right = function()
						local name = vim.t.tabname
						if not name or name == "" then
							return {}
						end
						return { { text = " [" .. name .. "] ", link = "Special" } }
					end,
				},
			},
		},
		keys = {
			{ "<C-x>n", "<cmd>BufferLineCycleNext<CR>", desc = "Next buffer" },
			{ "<C-x>p", "<cmd>BufferLineCyclePrev<CR>", desc = "Prev buffer" },

			-- 选择跳转 / 选择关闭
			{ "<C-x>o", "<cmd>BufferLinePick<CR>", desc = "Pick buffer" },
			{ "<C-x>k", "<cmd>BufferLinePickClose<CR>", desc = "Pick & close buffer" },
			{
				"<C-x>K",
				function() require("mini.bufremove").delete(0, true) end,
				desc = "Force close current buffer",
			},
			{ "<C-x>,", "<cmd>BufferLineMovePrev<CR>", desc = "Move buffer left" },
			{ "<C-x>.", "<cmd>BufferLineMoveNext<CR>", desc = "Move buffer right" },
			{
				"<C-x>0",
				function()
					local ok, br = pcall(require, "mini.bufremove")
					if ok then
						br.delete(0, false)
					else
						vim.cmd("bdelete")
					end
				end,
				desc = "Close current buffer",
			},
			-- C-x C-0 = 关掉其它 buffer。Ctrl+<数字> 没有传统控制码,只能靠 kitty/CSI-u
			-- 传输 —— 依赖 tmux.conf.local 的 extended-keys-format=csi-u(Ghostty 只认
			-- CSI-u,不认 xterm modifyOtherKeys)。否则会塌成裸 0,被更短的 <C-x>0(关当前)抢走。
			{ "<C-x><C-0>", "<cmd>BufferLineCloseOthers<CR>", desc = "Close other buffers" },
			{ "<C-x>[", "<cmd>BufferLineCloseLeft<CR>", desc = "Close buffers to the left" },
			{ "<C-x>]", "<cmd>BufferLineCloseRight<CR>", desc = "Close buffers to the right" },
		},
	},
}
