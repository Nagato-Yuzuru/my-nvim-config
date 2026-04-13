---
--- Obsidian.nvim — vault management inside Neovim
--- Keymaps: <localleader>o (,o) prefix
---   Vault 级: 任意 ft，文件在 vault 内即生效
---   Note 级:  markdown + vault 内才生效
--- 智能检测：向上查找 .obsidian/ 目录，自动识别 vault
---

--- 从指定路径向上查找 .obsidian/ 目录，返回 vault 根路径
local function find_vault(path)
	path = path or vim.fn.expand("%:p:h")
	local found = vim.fs.find(".obsidian", {
		upward = true,
		type = "directory",
		path = path,
	})
	if found[1] then
		return vim.fn.fnamemodify(found[1], ":h")
	end
	return nil
end

return {
	{
		"obsidian-nvim/obsidian.nvim",
		version = "*",
		lazy = true,
		event = "BufReadPost",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			-- 动态检测 vault：非 vault 内跳过 setup
			local vault = find_vault()
			if not vault then return end

			require("obsidian").setup({
				workspaces = {
					{ name = vim.fn.fnamemodify(vault, ":t"), path = vault },
				},

				-- 关闭旧命令格式（ObsidianXxx → Obsidian xxx）
				legacy_commands = false,

				-- render-markdown.nvim 已处理所有渲染，禁用内置 UI 避免冲突
				ui = { enable = false },

				-- blink.cmp 集成（自动注册 source）
				completion = {
					blink = { enabled = true },
					nvim_cmp = false,
				},

				-- 使用已有的 Snacks.picker
				picker = {
					name = "snacks.pick",
					note_mappings = {
						new = "<C-x>",
						insert_link = "<C-l>",
					},
					tag_mappings = {
						tag_note = "<C-x>",
						insert_tag = "<C-l>",
					},
				},

				-- 可读 slug，而非 Zettelkasten 时间戳
				---@param title string|nil
				---@return string
				note_id_func = function(title)
					if title then
						return title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
					end
					return tostring(os.time())
				end,

				daily_notes = {
					folder = "daily",
					date_format = "%Y-%m-%d",
					alias_format = "%B %-d, %Y",
					default_tags = { "daily" },
				},

				templates = {
					folder = "templates",
					date_format = "%Y-%m-%d",
					time_format = "%H:%M",
					substitutions = {
						yesterday = function() return os.date("%Y-%m-%d", os.time() - 86400) end,
						tomorrow  = function() return os.date("%Y-%m-%d", os.time() + 86400) end,
					},
				},

				-- 与 img-clip.nvim 保持一致
				attachments = { folder = "attachments" },

				-- ── Note 级键位：仅在 vault 内 markdown 中生效 ──────────────
				callbacks = {
					enter_note = function(_, _)
						local buf = vim.api.nvim_get_current_buf()
						local map = function(mode, lhs, rhs, desc)
							vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, desc = desc })
						end

						-- markdown 专属操作
						map("n", "<localleader>ob", "<cmd>Obsidian backlinks<CR>",       "Obsidian: Backlinks")
						map("n", "<localleader>ol", "<cmd>Obsidian links<CR>",           "Obsidian: Outgoing links")
						map("n", "<localleader>oc", "<cmd>Obsidian toggle_checkbox<CR>", "Obsidian: Toggle checkbox")
						map("n", "<localleader>or", "<cmd>Obsidian rename<CR>",          "Obsidian: Rename note")
						map("n", "<localleader>oi", "<cmd>Obsidian template<CR>",        "Obsidian: Insert template")

						-- 链接导航
						map("n", "gf", "<cmd>Obsidian follow_link<CR>", "Obsidian: Follow link")

						-- 可视模式
						map("v", "<localleader>ol", ":'<,'>Obsidian link<CR>",         "Obsidian: Link selection")
						map("v", "<localleader>on", ":'<,'>Obsidian link_new<CR>",     "Obsidian: Link to new note")
						map("v", "<localleader>oe", ":'<,'>Obsidian extract_note<CR>", "Obsidian: Extract to note")
					end,
				},
			})

			-- ── Vault 级键位：vault 内任意 ft 生效 ──────────────────────
			local function set_vault_keys(buf)
				local map = function(mode, lhs, rhs, desc)
					vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, desc = desc })
				end
				map("n", "<localleader>on", "<cmd>Obsidian new<CR>",          "Obsidian: New note")
				map("n", "<localleader>ot", "<cmd>Obsidian today<CR>",        "Obsidian: Today")
				map("n", "<localleader>oy", "<cmd>Obsidian yesterday<CR>",    "Obsidian: Yesterday")
				map("n", "<localleader>oT", "<cmd>Obsidian tomorrow<CR>",     "Obsidian: Tomorrow")
				map("n", "<localleader>of", "<cmd>Obsidian quick_switch<CR>", "Obsidian: Find note")
				map("n", "<localleader>os", "<cmd>Obsidian search<CR>",       "Obsidian: Search vault")
				map("n", "<localleader>ow", "<cmd>Obsidian workspace<CR>",    "Obsidian: Switch workspace")
				map("n", "<localleader>oo", "<cmd>Obsidian open<CR>",         "Obsidian: Open in app")
				map("n", "<localleader>otg","<cmd>Obsidian tags<CR>",         "Obsidian: Tags")
			end

			-- 当前 buffer 立即设置
			set_vault_keys(0)

			-- 后续在 vault 内打开的 buffer 也设置
			vim.api.nvim_create_autocmd("BufEnter", {
				group = vim.api.nvim_create_augroup("ObsidianVaultKeys", { clear = true }),
				callback = function(args)
					local bufpath = vim.api.nvim_buf_get_name(args.buf)
					if bufpath == "" then return end
					if find_vault(vim.fn.fnamemodify(bufpath, ":p:h")) then
						set_vault_keys(args.buf)
					end
				end,
			})
		end,
	},
}
