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

			-- golangci-lint v2：linter 完全自持，**不 require 上游 adapter**。两个理由：
			--   1. 上游模块 dofile 时就跑 `go env GOMOD` + `golangci-lint version`
			--      两个子进程（冷启动合计 ~150–220ms）猜 v1/v2 和路径模式，结果
			--      **永久缓存**；首次触发时 cwd 不在 Go module 里（或 buffer 不带
			--      name）就缓存到错误模式，之后每次 lint 都给 v2 喂错路径，exit 5
			--      (NoGoFiles)。直接按 v2 写死 args、目标路径每次 lint 重算，
			--      探测开销和缓存坑一起消失。
			--   2. 上游 parser 丢弃 Issues[].SuggestedFixes；per-diagnostic code
			--      action 靠它（tools/golangci_fix.lua + lsp/golangci_fix.lua）。
			-- v2 在 NoGoFiles / ErrorLogged 时非零 exit 是预期行为，不是 nvim-lint
			-- 该报警的 bug，故 ignore_exitcode。
			local function golangci_target()
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
			lint.linters.golangcilint = {
				cmd = "golangci-lint",
				append_fname = false,
				stream = "stdout",
				ignore_exitcode = true,
				args = {
					"run",
					"--output.json.path=stdout",
					-- 清空 .golangci.yml 可能声明的其它输出通道，保证 stdout 纯 JSON
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
					golangci_target, -- 每次 lint 重算，不缓存
				},
				parser = require("tools.golangci_fix").parser,
			}

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

			-- pint（cloudflare/pint）：Prometheus 规则文件 linter。同 actionlint——只对
			-- "看起来是规则文件"的 yaml 有意义（groups: + expr:），对普通 yaml 会误报，
			-- 故内容嗅探门控而非 LINTERS_BY_FT，首次命中时按需 Mason 安装。Mason 包名
			-- prometheus-pint（裸 `pint` 是 PHP 的 Laravel Pint），二进制也叫
			-- prometheus-pint，天然避开撞名。--json /dev/stdout 让 JSON 报告走 stdout、
			-- console 日志留 stderr，故 stream=stdout 收到纯 JSON 数组（schema：
			-- path/reporter/problem/details/severity/lines[]）。--offline 禁掉向
			-- Prometheus 发实时查询（编辑器无后端，免挂起/误报）。
			local pint_severity = {
				Fatal = vim.diagnostic.severity.ERROR,
				Bug = vim.diagnostic.severity.ERROR,
				Warning = vim.diagnostic.severity.WARN,
				Information = vim.diagnostic.severity.INFO,
			}
			lint.linters.prometheus_pint = {
				cmd = "prometheus-pint",
				-- 全局 flag（--offline/--no-color）必须在子命令 lint 之前（urfave/cli）。
				args = { "--offline", "--no-color", "lint", "--json", "/dev/stdout" },
				append_fname = true,
				stream = "stdout",
				ignore_exitcode = true, -- 有问题时 pint 非零退出属预期，不当 lint 崩溃
				parser = function(output, _bufnr)
					local diags = {}
					if not output or output == "" then
						return diags
					end
					local ok, reports = pcall(vim.json.decode, output)
					if not ok or type(reports) ~= "table" then
						return diags
					end
					for _, r in ipairs(reports) do
						local ls = r.lines or {}
						local first = ls[1] or 1
						local last = ls[#ls] or first
						local msg = r.problem or "pint problem"
						if r.details and r.details ~= "" then
							msg = msg .. "\n" .. r.details
						end
						table.insert(diags, {
							lnum = first - 1,
							end_lnum = last - 1,
							col = 0,
							severity = pint_severity[r.severity] or vim.diagnostic.severity.WARN,
							source = "pint",
							code = r.reporter,
							message = msg,
						})
					end
					return diags
				end,
			}

			-- 内容嗅探：Prometheus/Loki 规则文件的签名是顶层 `groups:` + 某处 `expr:`，
			-- 只扫前 200 行（都在靠前）。注意：Loki ruler 规则同 schema，会被一并 lint
			-- ——pint 按 PromQL 解析 LogQL 的 expr 可能误报，属已知取舍（本轮范围是
			-- PromQL；真要区分得靠 .pint.hcl 或路径约定）。
			local function is_prometheus_rule_file(bufnr)
				local has_groups, has_expr = false, false
				for _, l in ipairs(vim.api.nvim_buf_get_lines(bufnr or 0, 0, 200, false)) do
					if l:match("^groups:") then
						has_groups = true
					elseif l:match("^%s+expr:") then
						has_expr = true
					end
					if has_groups and has_expr then
						return true
					end
				end
				return false
			end

			local pint_install_triggered = false
			local function run_pint_if_applicable(bufnr)
				if not is_yaml_ft(vim.bo[bufnr].filetype) then
					return false, "not a yaml buffer"
				end
				if not is_prometheus_rule_file(bufnr) then
					return false, "not a prometheus rule file (no groups:/expr:)"
				end
				if vim.fn.executable("prometheus-pint") ~= 1 then
					if not pint_install_triggered then
						mason_ensure.ensure_tool("prometheus_pint")
						pint_install_triggered = true
					end
					return false, "prometheus-pint not on PATH (install triggered)"
				end
				lint.try_lint("prometheus_pint")
				return true, "dispatched"
			end

			vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
				callback = function(ev)
					local marker = root_markers[vim.bo.filetype]
					local cwd = marker and find_root(marker) or nil
					lint.try_lint(nil, { cwd = cwd })
					run_actionlint_if_applicable(ev.buf)
					run_pint_if_applicable(ev.buf)
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

			-- :PintRun — 对当前 buffer 强制跑一次 pint（若它是 Prometheus 规则文件）
			vim.api.nvim_create_user_command("PintRun", function()
				local ok, reason = run_pint_if_applicable(0)
				vim.notify(
					("pint: %s — %s"):format(ok and "dispatched" or "skipped", reason),
					ok and vim.log.levels.INFO or vim.log.levels.WARN
				)
			end, { desc = "Run pint on current buffer (if it's a Prometheus rule file)" })
		end,
	},
}
