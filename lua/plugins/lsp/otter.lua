return {
	{
		"jmbuhr/otter.nvim",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		cmd = { "OtterActivate", "OtterDeactivate" },
		opts = {
			lsp = {
				diagnostic_update_events = { "BufWritePost", "InsertLeave", "TextChanged" },
			},
			buffers = {
				set_filetype = true,
				write_to_disk = false,
			},
			handle_leading_whitespace = true,
			-- jq/awk 不在 otter 默认 extensions 表里——缺了会在 activate() 被静默过滤
			--（影子 buffer 路径需要扩展名）。deep-extend 只增不覆盖默认表。
			extensions = { jq = "jq", awk = "awk" },
		},
		config = function(_, opts)
			require("otter").setup(opts)
			vim.api.nvim_create_user_command(
				"OtterActivate",
				function() require("otter").activate() end,
				{ desc = "Otter: activate LSP in injected regions" }
			)
			vim.api.nvim_create_user_command(
				"OtterDeactivate",
				function() require("otter").deactivate() end,
				{ desc = "Otter: deactivate" }
			)

			-- WARN upstream bug（2.14.6 / pin f4a033d，仍是最新）：otter 自己的
			-- ExitPre 清理（OtterAutocloseOnQuit）只删影子 buffer，不清 raft、不停
			-- otter-ls、不撤 diagnostics augroup。退出被打断（未保存 E37）或 schedule
			-- 回调赶在退出前跑时，dropbar 等轮询方向 otter-ls 发请求，keeper.lua:368
			-- 读已死影子 → "Invalid buffer id" 报错循环（keeper 367 行只判 nil 不判
			-- validity）。本段在 config 层强制正确不变量：任一影子 buffer 死 ⇒ 整个
			-- raft 拆除（镜像 deactivate 的完整步骤）。副作用：被打断的退出会顺带
			-- 关掉该宿主的 otter，需重新 :OtterActivate。上游修复后删本段。
			local function teardown_raft(main_nr, raft)
				if raft.diagnostics_group then
					pcall(vim.api.nvim_del_augroup_by_id, raft.diagnostics_group)
				end
				if vim.api.nvim_buf_is_valid(main_nr) then
					for _, ns in pairs(raft.diagnostics_namespaces or {}) do
						vim.diagnostic.reset(ns, main_nr)
					end
				end
				local client_id = raft.otterls and raft.otterls.client_id
				if client_id then
					local client = vim.lsp.get_client_by_id(client_id)
					if client then
						client:stop(true)
					end
					if vim.api.nvim_buf_is_valid(main_nr) then
						pcall(vim.lsp.buf_detach_client, main_nr, client_id)
					end
				end
				for _, b in pairs(raft.buffers or {}) do
					if vim.api.nvim_buf_is_valid(b) then
						-- 同 deactivate：schedule 避 textlock。再入安全：rafts 已先置 nil。
						vim.schedule(function() pcall(vim.api.nvim_buf_delete, b, { force = true }) end)
					end
				end
			end

			vim.api.nvim_create_autocmd("BufWipeout", {
				group = vim.api.nvim_create_augroup("UserOtterShadowCleanup", { clear = true }),
				callback = function(ev)
					local keeper = require("otter.keeper")
					for main_nr, raft in pairs(keeper.rafts) do
						for _, otter_nr in pairs(raft.buffers or {}) do
							if otter_nr == ev.buf then
								keeper.rafts[main_nr] = nil
								teardown_raft(main_nr, raft)
								return
							end
						end
					end
				end,
			})
		end,
	},
}
