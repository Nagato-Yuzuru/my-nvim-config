-- 管理插件列表
require("lazy").setup({
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate", config = function()
      require("plugins.treesitter")
    end },
  
  -- Tokyonight color scheme
  { "folke/tokyonight.nvim", config = function()
      require("plugins.tokyonight")
    end },
  
  -- Tmux navigation
  { "christoomey/vim-tmux-navigator" },
  { "aserowy/tmux.nvim", config = function()
      require("plugins.tmux")
    end },

  -- Completion plugins
  { "hrsh7th/nvim-cmp",
    config = function()
      require("plugins.cmp")
    end
  },
  {"lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    ---@module "ibl"
    ---@type ibl.config
    opts = {},
    config = function()
      require("plugins.ibl")
    end
},
  {
    "kylechui/nvim-surround",
    config = function()
        require("nvim-surround").setup({})
        end
  },
  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-nvim-lua" },
  { "hrsh7th/cmp-cmdline" },
  { "saadparwaiz1/cmp_luasnip" },
  { "L3MON4D3/LuaSnip" },
  { "onsails/lspkind.nvim" },
  
  {
    'neovim/nvim-lspconfig',
    config = function()
      require("LSP.init")
    end,
  },
})

