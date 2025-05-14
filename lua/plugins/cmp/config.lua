local keymaps = {
    ['<C-u>'] = { 'scroll_documentation_up', 'fallback' },
    ['<C-d>'] = { 'scroll_documentation_down', 'fallback' },
    ['<Tab>'] = { "select_and_accept", "fallback" },
    ['<C-Esc>'] = { "hide", "fallback" },
    ['<C-p>'] = { "select_prev", "fallback" },
    ['<C-n>'] = { "select_next", "fallback" },
    ['<C-q>'] = { 'show_documentation', 'hide_documentation' },
    ['<A-/>'] = { "show", "fallback" },
    ['<C-y>'] = { "accept", "fallback" },
}

return {
    'saghen/blink.cmp',
    event = { 'BufReadPost', 'BufNewFile' },
    version = '1.*',
    dependencies = { 'xzbdmw/colorful-menu.nvim', opts = {} },
    opts = {
        completion = {


            documentation = {
                auto_show = true,
            },
            menu = {
                draw = {
                    columns = { { 'kind_icon' }, { 'label', gap = 1 } },
                    components = {
                        label = {
                            text = function(ctx)
                                return require('colorful-menu').blink_components_text(ctx)
                            end,
                            highlight = function(ctx)
                                return require('colorful-menu').blink_components_highlight(ctx)
                            end,
                        },
                    },
                },
            },


        },
        signature = {
            enabled = true,
        },
        keymap = keymaps,

        cmdline = {
            keymap = {
                preset = "inherit"
            },
            completion = {
                ghost_text = {
                    enabled = true,
                },
                menu = {
                    auto_show = true,
                },

            },
        },

        sources = {
            providers = {
                snippets = { score_offset = 1000 },
            },
        },
    },

}
