-- 管理插件列表
require("lazy").setup({ { "nvim-treesitter/nvim-treesitter", build =
    ":TSUpdate", config = function() require("plugins.treesitter") end },
    -- fzf
    { "junegunn/fzf", build = "./install --all", config = function()
        require("plugins.fzf") end }, { "junegunn/fzf.vim", },
    
    -- vim-indent-object
    { "michaeljsmith/vim-indent-object", },

    -- matchup.vim (增强 % 匹配)
    { "andymass/vim-matchup", event = "BufRead", },

    -- vim-cool (关闭高亮后增强搜索体验)
    { "romainl/vim-cool", event = "VeryLazy", },
 
    { "machakann/vim-highlightedyank" }, { "easymotion/vim-easymotion" },
    {'numToStr/Comment.nvim', config = function() require('Comment').setup()
    end },
    -- 增量搜索
    { "haya14busa/incsearch.vim" },
    -- 符号包围 输入法切换
    { "kylechui/nvim-surround", version = "*", event = "VeryLazy", config =
        function() require("nvim-surround").setup({ }) end },
    -- Tokyonight color scheme
    { "folke/tokyonight.nvim", config = function()
        require("plugins.tokyonight") end },
  
    -- Tmux navigation
    { "christoomey/vim-tmux-navigator" }, { "aserowy/tmux.nvim", config =
        function() require("plugins.tmux") end },

    -- Completion plugins
    { "hrsh7th/nvim-cmp", config = function() require("plugins.cmp") end },
    {"lukas-reineke/indent-blankline.nvim", main = "ibl",
        ---@module "ibl" @type ibl.config
        opts = {}, config = function() require("plugins.ibl") end }, {
        "hrsh7th/cmp-buffer" }, { "hrsh7th/cmp-path" }, {
        "hrsh7th/cmp-nvim-lsp" }, { "hrsh7th/cmp-nvim-lua" }, {
        "hrsh7th/cmp-cmdline" }, { "saadparwaiz1/cmp_luasnip" }, {
        "L3MON4D3/LuaSnip" }, { "onsails/lspkind.nvim" },
  
    { 'neovim/nvim-lspconfig', config = function() require("LSP.init") end, },
    { 'tpope/vim-fugitive', config = function() 
	    vim.api.nvim_set_keymap('n', 'gD', ':G<CR>', { noremap = true }) 
    end }, 
    { 'windwp/nvim-autopairs',     config = function()
      require('nvim-autopairs').setup{}
    end }
})

