-- Merge conflict 行内处理：高亮 <<<<<<< / ======= / >>>>>>> 块，提供 buffer-local
-- 键位一键选 ours/theirs/both/none。键位仅在检测到冲突的 buffer 激活，不污染全局。
--
-- 复杂场景（需要看 base、大段重叠）走 diffview 的 merge_tool：在冲突文件里
-- `:DiffviewOpen`，已配 diff3_mixed 布局（OURS | base | THEIRS | result）。
--
-- Buffer-local keymaps（plugin 默认，保留不改以匹配 git-conflict 文档习惯）：
--   co  choose ours           ct  choose theirs
--   cb  choose both           c0  choose none
--   ]x  next conflict         [x  prev conflict
--
-- 额外提供 :GitConflictListQf 把所有冲突塞 quickfix，方便跨文件批处理。
return {
	{
		"akinsho/git-conflict.nvim",
		version = "*",
		event = "BufReadPre",
		opts = {
			default_mappings = true,
			default_commands = true,
			disable_diagnostics = false,
			list_opener = "copen",
			highlights = {
				incoming = "DiffAdd",
				current = "DiffText",
			},
		},
		keys = {
			{ "<localleader>gx", "<cmd>GitConflictListQf<cr>", desc = "Git: list conflicts (qf)" },
		},
		init = function()
			-- 保存时若 buffer 仍含冲突标记，loud warning。git 本身不会阻止 commit
			-- 带 `<<<<<<<` 的文件——把它当文本处理。这里至少在保存层报警，避免
			-- 把残留标记 commit 进去。强一致性请配 git pre-commit hook（见文末注释）。
			vim.api.nvim_create_autocmd("BufWritePost", {
				group = vim.api.nvim_create_augroup("conflict-marker-guard", { clear = true }),
				callback = function(ev)
					if vim.bo[ev.buf].buftype ~= "" then
						return
					end
					local lines = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)
					for i, line in ipairs(lines) do
						if line:match("^<<<<<<<") or line:match("^=======$") or line:match("^>>>>>>>") then
							vim.notify(
								("Conflict marker still present at line %d — resolve before commit"):format(i),
								vim.log.levels.ERROR,
								{ title = "git-conflict" }
							)
							return
						end
					end
				end,
			})
		end,
	},
}
