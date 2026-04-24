return {
	{
		"mfussenegger/nvim-lint",
		event = "VeryLazy",
		config = function()
			local lint = require("lint")
			local mason_ensure = require("tools.mason_ensure")

			lint.linters_by_ft = mason_ensure.get_linters_by_ft()

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
			local function is_yaml_ft(ft)
				return ft == "yaml" or vim.startswith(ft or "", "yaml.")
			end
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

			vim.schedule(function()
				lint.try_lint()
			end)
		end,
	},
}
