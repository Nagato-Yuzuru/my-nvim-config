-- lua/tools/lsp_root.lua 的边界测试：M.resolve 三态（root string / false=单文件
-- / nil=跳过）与 $HOME 祖先防护。child 内 vim.uv.os_setenv 伪造 $HOME
--（uv.os_homedir 每次读环境变量），目录树铺在临时目录下，绝不碰真 home。

local H = require("tests.helpers")
local child, hooks = H.new_child()

local pre_restart = hooks.pre_case
hooks.pre_case = function()
	pre_restart()
	child.lua([[
		LR = require("tools.lsp_root")
		-- BASE/home 当假 $HOME；BASE 本身充当"home 的祖先"。realpath 消掉
		-- macOS /var → /private/var 的歧义，保证 buffer 名与 homedir 字符串可比。
		BASE = (function()
			local d = vim.fn.tempname() .. "-lsproot"
			vim.fn.mkdir(d .. "/home", "p")
			return vim.uv.fs_realpath(d)
		end)()
		HOME = BASE .. "/home"
		vim.uv.os_setenv("HOME", HOME)
		function MK(rel) vim.fn.mkdir(HOME .. "/" .. rel, "p") end
		-- resolve 只看 buffer 名，文件本身不用存在；父目录要在（marker 扫描）。
		function BUF_AT(abs)
			vim.cmd.edit(abs)
			return vim.api.nvim_get_current_buf()
		end
		function RESOLVE(rel, markers, unnamed_cwd)
			return LR.resolve(BUF_AT(HOME .. "/" .. rel), markers or { ".git" }, unnamed_cwd)
		end
	]])
end

local T = MiniTest.new_set({ hooks = hooks })
local eq = MiniTest.expect.equality

T["fake HOME is effective (uv.os_homedir follows os_setenv)"] = function()
	eq(child.lua_get("vim.uv.os_homedir()"), child.lua_get("HOME"))
end

T["marker inside home: project root found from nested buffer"] = function()
	child.lua([[MK("proj/.git"); MK("proj/sub")]])
	eq(child.lua_get([[RESOLVE("proj/sub/f.lua")]]), child.lua_get("HOME") .. "/proj")
end

T["buffer directly at project root resolves to that root"] = function()
	child.lua([[MK("proj/.git")]])
	eq(child.lua_get([[RESOLVE("proj/f.lua")]]), child.lua_get("HOME") .. "/proj")
end

T["marker at $HOME itself degrades to single-file (false), not root=$HOME"] = function()
	child.lua([[MK(".git"); MK("plain")]])
	eq(child.lua_get([[RESOLVE("plain/f.py")]]), false)
end

T["marker above $HOME (ancestor) also degrades to single-file"] = function()
	child.lua([[vim.fn.mkdir(BASE .. "/.git", "p"); MK("x")]])
	eq(child.lua_get([[RESOLVE("x/f.lua")]]), false)
end

T["no marker, file directly in $HOME: single-file mode"] = function() eq(child.lua_get([[RESOLVE("f.py")]]), false) end

T["no marker, file in a small dir below home: that dir becomes root"] = function()
	child.lua([[MK("scripts")]])
	eq(child.lua_get([[RESOLVE("scripts/f.py")]]), child.lua_get("HOME") .. "/scripts")
end

T["conjure-log buffer is skipped entirely (nil)"] = function()
	child.lua([[MK("proj/.git")]])
	eq(child.lua_get([[RESOLVE("proj/conjure-log-42.rkt") == nil]]), true)
end

T["unnamed buffer: default is skip (nil)"] = function()
	child.lua([[vim.cmd.enew()]])
	eq(child.lua_get([[LR.resolve(vim.api.nvim_get_current_buf(), { ".git" }) == nil]]), true)
end

T["unnamed buffer with unnamed_cwd: cwd becomes root, no marker walk"] = function()
	child.lua([[
		MK("proj/.git")
		MK("proj/sub")
		vim.cmd.cd(HOME .. "/proj/sub")
		vim.cmd.enew()
	]])
	-- 注意语义：unnamed 分支直接用 cwd，不做 marker 上溯——所以是 sub 而非 proj
	eq(
		child.lua_get([[LR.resolve(vim.api.nvim_get_current_buf(), { ".git" }, true)]]),
		child.lua_get("HOME") .. "/proj/sub"
	)
end

T["unnamed buffer with unnamed_cwd at $HOME: single-file, never a workspace"] = function()
	child.lua([[
		vim.cmd.cd(HOME)
		vim.cmd.enew()
	]])
	eq(child.lua_get([[LR.resolve(vim.api.nvim_get_current_buf(), { ".git" }, true)]]), false)
end

-- 防护是字符串比较，不做 realpath——安全的前提是 buffer 名永远是解析后的
-- 路径。nvim 在 :edit 和 nvim_buf_set_name 两个入口都自己解析 symlink，
-- 所以经 symlink 指到 $HOME 的路径照样命中防护。此用例钉住这个前提。
T["symlink to $HOME in bufname: nvim resolves it, guard still holds"] = function()
	child.lua([[
		LINK = BASE .. "/link-home"
		vim.uv.fs_symlink(HOME, LINK)
		local buf = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(buf, LINK .. "/f.py")
		GOT = LR.resolve(buf, { ".git" })
	]])
	eq(child.lua_get("GOT"), false)
end

-- root_dir() wrapper：三态到 on_dir 协议的翻译
T["root_dir wrapper: string root → on_dir(root)"] = function()
	child.lua([[
		MK("proj/.git")
		CALLS, ARG = 0, "sentinel"
		LR.root_dir({ ".git" })(BUF_AT(HOME .. "/proj/f.lua"), function(root)
			CALLS, ARG = CALLS + 1, root
		end)
	]])
	eq(child.lua_get("CALLS"), 1)
	eq(child.lua_get("ARG"), child.lua_get("HOME") .. "/proj")
end

T["root_dir wrapper: single-file → on_dir(nil)"] = function()
	child.lua([[
		CALLS, ARG = 0, "sentinel"
		LR.root_dir({ ".git" })(BUF_AT(HOME .. "/f.py"), function(root)
			CALLS, ARG = CALLS + 1, root
		end)
	]])
	eq(child.lua_get("CALLS"), 1)
	eq(child.lua_get("ARG == nil"), true)
end

T["root_dir wrapper: skip → on_dir not called"] = function()
	child.lua([[
		CALLS = 0
		LR.root_dir({ ".git" })(BUF_AT(HOME .. "/conjure-log-1.scm"), function()
			CALLS = CALLS + 1
		end)
	]])
	eq(child.lua_get("CALLS"), 0)
end

return T
