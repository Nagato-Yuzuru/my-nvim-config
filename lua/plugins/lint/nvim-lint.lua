return {
	{
		"mfussenegger/nvim-lint",
		-- VeryLazy 触发太晚：会错过启动时打开的第一个 buffer 的 BufReadPost。
		-- BufReadPre / BufNewFile 在第一个文件加载前就把 plugin 挂上，下面的
		-- BufReadPost 自动命中。
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			local lint = require("lint")
			local mason_ensure = require("tools.mason_ensure")

			lint.linters_by_ft = mason_ensure.get_linters_by_ft()

			-- swiftlint 由 mise 提供，不像 mason 系会被 ensure_for_ft 异步兜底安装：
			-- 缺失时 uv.spawn 每次 lint 都刷 ERROR（lint.lua:437，非 notify_once）。故
			-- 仅在二进制在 PATH 上时才保留 swift 条目；`mise use aqua:realm/SwiftLint`
			-- 装好后重启 nvim 生效（同 Scheme LSP 的探测-后-启用策略）。sourcekit-lsp
			-- 的诊断不受影响。
			if vim.fn.executable("swiftlint") ~= 1 then
				lint.linters_by_ft.swift = nil
			end

			-- zsh `-n`（no-exec syntax check）：zsh 没有可靠 LSP / shellcheck 支持，
			-- 用解释器自己的 parse-only 模式抓硬语法错。zsh 是系统二进制，不进 Mason。
			-- 走 `/dev/stdin`：nvim-lint 把 buffer 内容喂进 stdin，zsh 把 /dev/stdin
			-- 当文件路径读，输出带行号的 `/dev/stdin:LINE: msg` —— 这样 lint 不依
			-- 赖磁盘内容，InsertLeave 时也能拿到未保存改动的实时诊断。
			-- （裸 `zsh -n` 读 stdin 不输出行号，所以必须走 /dev/stdin。）
			lint.linters.zsh_n = {
				cmd = "zsh",
				stdin = true,
				args = { "-n", "/dev/stdin" },
				append_fname = false,
				stream = "stderr",
				ignore_exitcode = true,
				-- 不捕 file:nvim-lint 会按 file 字段筛 buffer,zsh 输出的路径
				-- (绝对、可能含 /private 前缀或 symlink)经常跟 expand('%:p') 不
				-- 等,捕了反而被过滤掉。直接让 nvim-lint 绑当前 buffer。
				parser = require("lint.parser").from_pattern(
					"[^:]+:(%d+): (.+)",
					{ "lnum", "message" },
					nil,
					{ ["source"] = "zsh -n", ["severity"] = vim.diagnostic.severity.ERROR }
				),
			}
			lint.linters_by_ft.zsh = { "zsh_n" }

			-- golangci-lint v2 override（延迟应用，见 ensure_golangcilint_override）：
			-- 上游 adapter 的 getArgs() 在模块 dofile 时跑一次 `go env GOMOD` +
			-- 一次 `golangci-lint version`（两个子进程，冷启动合计 ~150–220ms）
			-- 来决定后续传"目录"还是"文件路径"，结果**永久缓存**。如果首次
			-- 触发时 nvim 的 cwd 不在 Go module 里（或 buffer 不带 name），
			-- 缓存到错误模式后所有后续 lint 都给 v2 喂错路径，exit 5
			-- (NoGoFiles)。这里强制每次 lint 重新解析 + 忽略 exit code
			-- (v2 在 NoGoFiles / ErrorLogged 时也会非零 exit，那是预期行为，
			-- 不是 nvim-lint 该报警的 bug)。
			--
			-- 为什么惰性：读 `lint.linters.golangcilint` 会触发上游模块 require，
			-- 连带跑上面那两个子进程。若在 config() 里直接 override，等于**每次
			-- 启动**打开任意文件（连非 Go 的都算，plugin 挂在 BufReadPre）都白付
			-- ~150–220ms —— 且 override 把 args 整个换掉，getArgs() 的结果根本没
			-- 用上。因此包成一次性函数，只在首个 Go buffer 真要 lint 时应用一次
			-- （下方 autocmd 里 ft=="go" 时调用），把这笔开销移出启动路径。
			local golangcilint_patched = false
			local function ensure_golangcilint_override()
				if golangcilint_patched then
					return
				end
				golangcilint_patched = true

				local function go_args()
					local bufname = vim.api.nvim_buf_get_name(0)
					if bufname == "" then
						return nil
					end
					local buf_dir = vim.fn.fnamemodify(bufname, ":h")
					local has_mod = vim.fs.find("go.mod", { path = buf_dir, upward = true })[1] ~= nil
					-- Module 内：传目录让 v2 自己处理 package 边界。
					-- Module 外：传文件路径走 single-file 模式。
					return has_mod and buf_dir or bufname
				end

				lint.linters.golangcilint = vim.tbl_deep_extend("force", lint.linters.golangcilint or {}, {
					ignore_exitcode = true,
					args = {
						"run",
						"--output.json.path=stdout",
						"--output.text.path=",
						"--output.tab.path=",
						"--output.html.path=",
						"--output.checkstyle.path=",
						"--output.code-climate.path=",
						"--output.junit-xml.path=",
						"--output.teamcity.path=",
						"--output.sarif.path=",
						"--issues-exit-code=0",
						"--show-stats=false",
						"--path-mode=abs",
						go_args, -- 每次 lint 重算，不缓存
					},
				})
			end

			-- Find the nearest ancestor directory containing `filename`.
			local function find_root(filename)
				local buf_dir = vim.fn.expand("%:p:h")
				local found = vim.fs.find(filename, { path = buf_dir, upward = true })[1]
				return found and vim.fn.fnamemodify(found, ":h") or nil
			end

			-- Per-filetype root markers for monorepo-friendly cwd.
			local root_markers = {
				go = "go.mod",
			}

			-- actionlint 只对 GitHub Actions workflow 有意义；对普通 YAML 会
			-- 误报（schema 对不上）。路径触发而非 LINTERS_BY_FT，并在首次
			-- 命中时按需走 Mason 安装。
			local function is_gh_workflow(bufnr)
				local p = vim.api.nvim_buf_get_name(bufnr or 0)
				if p == "" then
					return false
				end
				return p:match("%.github/workflows/.*%.ya?ml$") ~= nil
			end
			-- ft 不限死 "yaml"：有些设置会把 workflow 文件识别为 yaml.xxx
			-- 复合 ft；反正 is_gh_workflow() 已经收敛到正确路径，ft 只需要
			-- 是 yaml 开头即可。
			local function is_yaml_ft(ft) return ft == "yaml" or vim.startswith(ft or "", "yaml.") end
			-- Mason 安装是异步的；try_lint 必须等二进制真的在 PATH 上才跑，
			-- 否则首次打开 workflow 文件会报 ENOENT。
			--   install_triggered：防止首次窗口内重复 kick 安装
			--   每次进入命令体重新 executable() 检查，装好后下一次 save/
			--   InsertLeave 自动拉起 lint。
			local actionlint_install_triggered = false

			local function run_actionlint_if_applicable(bufnr)
				if not (is_yaml_ft(vim.bo[bufnr].filetype) and is_gh_workflow(bufnr)) then
					return false, "not a gh-workflow yaml buffer"
				end
				if vim.fn.executable("actionlint") ~= 1 then
					if not actionlint_install_triggered then
						mason_ensure.ensure_tool("actionlint")
						actionlint_install_triggered = true
					end
					return false, "actionlint not on PATH (install triggered)"
				end
				lint.try_lint("actionlint")
				return true, "dispatched"
			end

			vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
				callback = function(ev)
					local ft = vim.bo.filetype
					-- 首个 Go buffer 才把 golangcilint override 挂上（连带触发上游
					-- 模块 require + 两个子进程）；try_lint 之前应用，第一次 Go lint
					-- 就用上修正后的 args。非 Go buffer 永不付这笔开销。
					if ft == "go" then
						ensure_golangcilint_override()
					end
					local marker = root_markers[ft]
					local cwd = marker and find_root(marker) or nil
					lint.try_lint(nil, { cwd = cwd })
					run_actionlint_if_applicable(ev.buf)
				end,
			})

			-- 手动触发命令（调试/强制跑一次用）：:ActionlintRun
			vim.api.nvim_create_user_command("ActionlintRun", function()
				local ok, reason = run_actionlint_if_applicable(0)
				vim.notify(
					("actionlint: %s — %s"):format(ok and "dispatched" or "skipped", reason),
					ok and vim.log.levels.INFO or vim.log.levels.WARN
				)
			end, { desc = "Run actionlint on current buffer (if it's a GH workflow)" })
		end,
	},
}
