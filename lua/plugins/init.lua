local cmp = require("plugins.cmp.config")

require("lazy").setup({
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			require("plugins.treesitter")
		end,
	},
	{
		"mhinz/vim-signify",
		event = "BufRead",
		config = function()
			vim.g.signify_sign_add = "+"
			vim.g.signify_sign_change = "~"
			vim.g.signify_sign_delete = "-"
			vim.g.signify_sign_show_count = 1
		end,
	},
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		config = function()
			require("which-key").setup({})
		end,
	},
	{
		"junegunn/fzf",
		build = "./install --all",
		config = function()
			require("plugins.fzf")
		end,
	},
	{ "junegunn/fzf.vim" },

	-- vim-indent-object
	{ "michaeljsmith/vim-indent-object" },

	-- matchup.vim (增强 % 匹配)
	{ "andymass/vim-matchup", event = "BufRead" },

	-- vim-cool (关闭高亮后增强搜索体验)
	{ "romainl/vim-cool", event = "VeryLazy" },

	{ "machakann/vim-highlightedyank" },

	{
		"akinsho/bufferline.nvim",
		config = function()
			require("plugins.bufferline")
		end,
	},
	{
		"fgheng/winbar.nvim",
		config = function()
			require("winbar").setup({
				enabled = true,
				show_file_name = true,
			})
		end,
	},
	{
		"akinsho/toggleterm.nvim",
		config = function()
			require("plugins.toggleterm")
		end,
	},
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v2.x",
		config = function()
			require("neo-tree").setup()
		end,
		dependencies = {
			"MunifTanjim/nui.nvim",
		},
	},
	{
		"easymotion/vim-easymotion",
		config = function()
			require("plugins.easymotion")
		end,
	},
	{
		"numToStr/Comment.nvim",
		config = function()
			require("Comment").setup()
		end,
	},
	-- 增量搜索
	{ "haya14busa/incsearch.vim" },
	-- 符号包围 输入法切换
	{
		"kylechui/nvim-surround",
		version = "*",
		event = "VeryLazy",
		config = function()
			require("nvim-surround").setup({})
		end,
	},
	-- Tokyonight color scheme
	{
		"folke/tokyonight.nvim",
		config = function()
			require("plugins.tokyonight")
		end,
	},

	-- Tmux navigation
	{
		"aserowy/tmux.nvim",
		config = function()
			require("plugins.tmux")
		end,
	},

	-- Completion plugins
	cmp,

	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		---@module "ibl" @type ibl.config
		opts = {},
		config = function()
			require("plugins.ibl")
		end,
	},
	{
		"L3MON4D3/LuaSnip",
	},
	{ "onsails/lspkind.nvim" },

	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"williamboman/mason-lspconfig.nvim",
		},
		config = function()
			require("LSP.init")
		end,
	},
	{
		"tpope/vim-fugitive",
		config = function()
			vim.api.nvim_set_keymap("n", "gD", ":G<CR>", { noremap = true })
		end,
	},
	{
		"windwp/nvim-autopairs",
		config = function()
			require("nvim-autopairs").setup({})
		end,
	},

	{
		"nvimtools/none-ls.nvim",
		config = function()
			require("plugins.none-ls")()
		end,
		dependencies = {
			"nvimtools/none-ls-extras.nvim",
			"nvim-lua/plenary.nvim",
		},
	},
	{
		"williamboman/mason.nvim",
		config = function()
			require("plugins.mason.mason")
		end,
	},

	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		-- 明确声明它依赖 mason.nvim
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			-- 在这里配置 mason-tool-installer
			require("plugins.mason.installer")
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		lazy = false,
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("plugins.mason.lspconfig")
		end,
	},
	{
		"jay-babu/mason-null-ls.nvim",
		dependencies = { "williamboman/mason.nvim", "nvimtools/none-ls.nvim" },
		config = function()
			require("mason-null-ls").setup({
				-- 你的 mason-null-ls 配置
				automatic_installation = true,
				handlers = {},
			})
		end,
	},
	{
		"jay-babu/mason-nvim-dap.nvim",
		dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
		config = function()
			require("mason-nvim-dap").setup({
				-- 你的 mason-nvim-dap 配置
				-- 例如: automatic_installation = true

				automatic_installation = true,
				handlers = {},
			})
		end,
	},
	require("plugins.ft.markdown"),
})
