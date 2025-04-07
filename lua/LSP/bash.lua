-- ./lua/LSP/bash
-- shell script formatter
vim.api.nvim_exec([[
  autocmd FileType sh,bash,zsh setlocal formatprg=shfmt\ -ci\ -i\ 2
]], false)

local lspconfig = require('lspconfig')

lspconfig.bashls.setup({})
