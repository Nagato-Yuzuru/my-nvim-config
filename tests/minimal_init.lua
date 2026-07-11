-- Headless 测试环境（mini.test 约定的 minimal init）。
--
-- 跑法（repo 根目录）：
--   nvim --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()"
-- 单文件：
--   nvim --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run_file('tests/test_wrap.lua')"
--
-- 职责：
--   1. rtp = 本仓 + .deps 测试依赖（不加载 lazy.nvim / 用户配置——测的是
--      lua/tools/* 的自有逻辑，不是整套配置）
--   2. .deps 自举：mini.test / deleft.vim 按 lazy-lock.json 的 commit 克隆
--      （与 lazy 同一事实源，lock 更新后这里自动对齐）；python/go treesitter
--      parser 从钉死 tag 的 grammar 源码编译（测试只要 .so，不需要
--      nvim-treesitter 的 query / 安装器）
--   3. 每个 test case 的 child process 也用本文件启动（见 tests/helpers.lua）
--
-- 环境依赖：git、cc（开发机与 CI runner 都有）。

local here = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.dirname(vim.fs.dirname(here))
local deps = root .. "/.deps"

local function sh(cmd)
	local res = vim.system(cmd, { text = true }):wait()
	assert(res.code == 0, ("[minimal_init] `%s` failed:\n%s"):format(table.concat(cmd, " "), res.stderr or ""))
end

-- 插件 commit 的单一事实源是 lazy-lock.json；测试依赖跟随它，不另立 pin。
local lock
local function locked_commit(name)
	if not lock then
		local f = assert(io.open(root .. "/lazy-lock.json", "r"))
		lock = vim.json.decode(f:read("*a"))
		f:close()
	end
	return assert(lock[name], name .. " missing from lazy-lock.json").commit
end

-- clone（缺失时）+ checkout 到 lock 的 commit（lock 更新后旧 clone 自动对齐）。
local function ensure_plugin(name, url)
	local dir = deps .. "/" .. name
	if not vim.uv.fs_stat(dir) then
		sh({ "git", "clone", "--quiet", "--filter=blob:none", url, dir })
	end
	local commit = locked_commit(name)
	local head = vim.system({ "git", "-C", dir, "rev-parse", "HEAD" }, { text = true }):wait()
	if not vim.startswith(head.stdout or "", commit) then
		if vim.system({ "git", "-C", dir, "cat-file", "-e", commit .. "^{commit}" }):wait().code ~= 0 then
			sh({ "git", "-C", dir, "fetch", "--quiet", "origin", commit })
		end
		sh({ "git", "-C", dir, "checkout", "--quiet", commit })
	end
	return dir
end

-- wrap.lua 的 treesitter 剥壳要真 parser：lua 用 nvim 自带的，python/go 从
-- grammar 源码编译。产物文件名含 tag，tag 升级后旧 .so 自动作废重编。
local PARSERS = {
	python = { url = "https://github.com/tree-sitter/tree-sitter-python", tag = "v0.25.0", scanner = true },
	go = { url = "https://github.com/tree-sitter/tree-sitter-go", tag = "v0.25.0" },
}

local function ensure_parser(lang, spec)
	local so = ("%s/parsers/%s-%s.so"):format(deps, lang, spec.tag)
	if not vim.uv.fs_stat(so) then
		local src = ("%s/src/tree-sitter-%s-%s"):format(deps, lang, spec.tag)
		if not vim.uv.fs_stat(src) then
			sh({ "git", "clone", "--quiet", "--depth", "1", "--branch", spec.tag, spec.url, src })
		end
		vim.fn.mkdir(deps .. "/parsers", "p")
		local cc = { "cc", "-shared", "-fPIC", "-O2", "-I", src .. "/src", src .. "/src/parser.c" }
		if spec.scanner then
			table.insert(cc, src .. "/src/scanner.c")
		end
		vim.list_extend(cc, { "-o", so })
		sh(cc)
	end
	vim.treesitter.language.add(lang, { path = so })
end

vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(ensure_plugin("mini.test", "https://github.com/nvim-mini/mini.test"))
vim.opt.runtimepath:append(ensure_plugin("deleft.vim", "https://github.com/AndrewRadev/deleft.vim"))
-- image_render 直接复用 snacks.image.doc 的 url_decode/transforms(该模块不碰
-- Snacks 全局,可独立 require)。只挂 package.path 暴露其 lua 模块,**不上
-- rtp**:mini.test 的 child 不带 --noplugin,rtp 上的 snacks 会在 plugin/ 阶段
-- 被 source、定义 Snacks 全局,破坏「snacks 缺席」类用例的前提(bugs #12)。
local snacks_dir = ensure_plugin("snacks.nvim", "https://github.com/folke/snacks.nvim")
package.path = ("%s;%s/lua/?.lua;%s/lua/?/init.lua"):format(package.path, snacks_dir, snacks_dir)

for lang, spec in pairs(PARSERS) do
	ensure_parser(lang, spec)
end

-- 生产侧的 matchit 兼容层由 vim-matchup 提供（plugins/edit/wrap.lua）；测试
-- 环境走 deleft 自己文档化的回落：内建 matchit。b:match_words 来自 $VIMRUNTIME
-- 的 ftplugin，--noplugin 下 filetype 机制要手动开。
vim.g.deleft_mapping = "" -- 同生产配置：不占默认 dh 键
vim.cmd.packadd("matchit")
vim.cmd("runtime! plugin/deleft.vim") -- --noplugin 不 source rtp 里的插件，手动来
vim.cmd("filetype plugin indent on")

vim.o.swapfile = false
require("mini.test").setup()
