local cmp = require'cmp'

cmp.setup({
    snippet = {
        expand = function(args)
            require('luasnip').lsp_expand(args.body) -- 使用 LuaSnip 作为代码片段引擎
        end,
    },
    mapping = {
        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-e>'] = cmp.mapping.abort(),
        ['<Tab>'] = cmp.mapping.confirm({ select = true }),
	['<C-Space>'] = cmp.mapping.complete(),
	        -- 使用 C-p 和 C-n 来选择补全项
        ['<C-p>'] = cmp.mapping.select_prev_item(), -- 选择上一个补全项
        ['<C-n>'] = cmp.mapping.select_next_item() -- 选择下一个补全项

    },
    sources = cmp.config.sources({
        { name = 'nvim_lsp' },
        { name = 'luasnip' },
    }, {
        { name = 'buffer' },
        { name = 'path' },
    }),
    formatting = {
        format = require('lspkind').cmp_format({ with_text = true, maxwidth = 50 })
    }
})

-- 自定义高亮当前选中的补全项
vim.cmd([[
  hi CmpItemSelected guibg=#5e81ac guifg=#ffffff
  hi CmpItemAbbrDeprecated guifg=#808080 gui=strikethrough
  hi CmpItemAbbrMatch guibg=#88c0d0 guifg=#2e3440
  hi CmpItemAbbrMatchFuzzy guibg=#88c0d0 guifg=#2e3440
  hi CmpItemKind guifg=#81a1c1
]])

-- 针对命令行模式的补全
cmp.setup.cmdline(':', {
    sources = cmp.config.sources({
        { name = 'path' }
    }, {
        { name = 'cmdline' }
    })
})

