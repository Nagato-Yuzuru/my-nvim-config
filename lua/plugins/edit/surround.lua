---
--- Created by colas.
--- DateTime: 2025/11/4 18:50
---
return {
    {
        "kylechui/nvim-surround",
        version = "*",
        event = "VeryLazy",
        opts = {
            -- 保持默认键位：ys/ds/cs，Visual 下 S
            -- 还支持 yss（整行）、yS（块状）等
            aliases = {
                ["<"] = "t"
            }
        },
    },
}
