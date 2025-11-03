---
--- Created by colas.
--- DateTime: 2025/11/3 20:07
---
-- plugins/ui/tmux.lua
return {
    {
        "aserowy/tmux.nvim",
        opts = {
            navigation = {
                enable_default_keybindings = true, -- <C-h/j/k/l> 直通 tmux pane
                persist_zoom = true,
            },
            resize = { enable_default_keybindings = false },
            copy_sync = {
                enable = true, -- 复制到系统剪贴板
            },
        },
    },
}
