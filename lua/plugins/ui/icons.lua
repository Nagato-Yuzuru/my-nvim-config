return {
	{
		"echasnovski/mini.icons",
		lazy = false,
		priority = 999, -- tokyonight(1000) の直後
		opts = {
			directory = {
				-- 常见顶层目录
				[".github"] = { glyph = "󰊤", hl = "MiniIconsYellow" },
				[".idea"] = { glyph = "󰈎", hl = "MiniIconsOrange" },
				[".vscode"] = { glyph = "󰨞", hl = "MiniIconsBlue" },
				src = { glyph = "󰴉", hl = "MiniIconsCyan" },
				lib = { glyph = "󰂺", hl = "MiniIconsYellow" },
				scripts = { glyph = "󰜈", hl = "MiniIconsGreen" },
				bin = { glyph = "󰜈", hl = "MiniIconsGreen" },
				docs = { glyph = "󰈙", hl = "MiniIconsBlue" },
				doc = { glyph = "󰈙", hl = "MiniIconsBlue" },
				test = { glyph = "󰙨", hl = "MiniIconsOrange" },
				tests = { glyph = "󰙨", hl = "MiniIconsOrange" },
				spec = { glyph = "󰙨", hl = "MiniIconsOrange" },
				config = { glyph = "󰒓", hl = "MiniIconsGrey" },
				cmd = { glyph = "󰘳", hl = "MiniIconsGreen" },
				internal = { glyph = "󰒃", hl = "MiniIconsRed" },
				pkg = { glyph = "󰏗", hl = "MiniIconsPurple" },
				assets = { glyph = "󰉏", hl = "MiniIconsYellow" },
				static = { glyph = "󰉏", hl = "MiniIconsYellow" },
				public = { glyph = "󰉏", hl = "MiniIconsYellow" },
				dist = { glyph = "󰏔", hl = "MiniIconsOrange" },
				build = { glyph = "󰏔", hl = "MiniIconsOrange" },
				-- Go
				api = { glyph = "󰒍", hl = "MiniIconsCyan" },
				-- infra / devops
				deploy = { glyph = "󰜟", hl = "MiniIconsPurple" },
				terraform = { glyph = "󱁢", hl = "MiniIconsPurple" },
				k8s = { glyph = "󱃾", hl = "MiniIconsBlue" },
				-- lua / nvim
				lua = { glyph = "󰢱", hl = "MiniIconsBlue" },
				plugin = { glyph = "󰐱", hl = "MiniIconsCyan" },
				plugins = { glyph = "󰐱", hl = "MiniIconsCyan" },
				core = { glyph = "󰘨", hl = "MiniIconsRed" },
				lsp = { glyph = "󰗊", hl = "MiniIconsGreen" },
			},
		},
		init = function()
			-- mini.icons 透明接管 nvim-web-devicons 调用
			package.preload["nvim-web-devicons"] = function()
				require("mini.icons").mock_nvim_web_devicons()
				return package.loaded["nvim-web-devicons"]
			end
		end,
	},
}
