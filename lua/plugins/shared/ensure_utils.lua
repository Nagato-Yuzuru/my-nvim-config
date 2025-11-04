---
--- Created by colas.
--- DateTime: 2025/11/4 13:35
---
local M = {}

function M.has_exec(bin) return vim.fn.executable(bin) == 1 end

function M.ensure_mason_pkg(pkg_name)
    local ok, mr = pcall(require, "mason-registry"); if not ok then return end
    local okp, pkg = pcall(mr.get_package, pkg_name); if not okp then return end
    if not pkg:is_installed() then
        vim.notify(("Installing %s via Mason…"):format(pkg_name), vim.log.levels.INFO)
        pkg:install()
    end
end

-- 根据 “formatter/linters 名称 → {bin, mason}” 映射列表，缺失时自动安装
function M.ensure_tools(list, tool_map)
    if vim.env.CI == "true" or vim.env.NO_AUTO_INSTALL == "1" then return end
    for _, name in ipairs(list) do
        local t = tool_map[name]
        if t and not M.has_exec(t.bin) then
            M.ensure_mason_pkg(t.mason)
        end
    end
end

return M
