---
--- Obsidian.nvim — vault management inside Neovim
--- Keymaps: <localleader>o (,o) prefix
---
return {
	{
		"obsidian-nvim/obsidian.nvim",
		version = "*",
		lazy = true,
		ft = "markdown",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			-- 自动检测：从 CWD 向上查找含 .obsidian/ 的目录
			workspaces = {
				{
					name = "auto",
					path = function()
						local dir = vim.fn.getcwd()
						repeat
							if vim.fn.isdirectory(dir .. "/.obsidian") == 1 then
								return dir
							end
							local parent = vim.fn.fnamemodify(dir, ":h")
							if parent == dir then break end
							dir = parent
						until false
						return vim.fn.getcwd()
					end,
				},
			},

			-- render-markdown.nvim already handles concealing, checkboxes, callouts, wikilinks
			ui = { enable = false },

			-- blink.cmp integration (auto-registers as source)
			completion = {
				blink = { enabled = true },
				nvim_cmp = false,
			},

			-- use existing Snacks.picker
			picker = { name = "snacks.pick" },

			-- 新命令格式，关闭旧格式警告
			legacy_commands = false,

			-- readable title-based slugs
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
				default_tags = { "daily" },
			},

			templates = {
				folder = "templates",
				date_format = "%Y-%m-%d",
				time_format = "%H:%M",
			},

			attachments = {
				folder = "attachments",
			},
		},
		keys = {
			-- normal mode — all under ,o (新命令格式)
			{ "<localleader>on", "<cmd>Obsidian new<cr>",             desc = "Obsidian: New note" },
			{ "<localleader>ot", "<cmd>Obsidian today<cr>",           desc = "Obsidian: Today's daily" },
			{ "<localleader>oy", "<cmd>Obsidian yesterday<cr>",       desc = "Obsidian: Yesterday" },
			{ "<localleader>oT", "<cmd>Obsidian tomorrow<cr>",        desc = "Obsidian: Tomorrow" },
			{ "<localleader>of", "<cmd>Obsidian quick_switch<cr>",    desc = "Obsidian: Find note" },
			{ "<localleader>os", "<cmd>Obsidian search<cr>",          desc = "Obsidian: Grep vault" },
			{ "<localleader>ob", "<cmd>Obsidian backlinks<cr>",       desc = "Obsidian: Backlinks" },
			{ "<localleader>ol", "<cmd>Obsidian links<cr>",           desc = "Obsidian: Outgoing links" },
			{ "<localleader>oc", "<cmd>Obsidian toggle_checkbox<cr>", desc = "Obsidian: Toggle checkbox" },
			{ "<localleader>or", "<cmd>Obsidian rename<cr>",          desc = "Obsidian: Rename (updates refs)" },
			{ "<localleader>ow", "<cmd>Obsidian workspace<cr>",       desc = "Obsidian: Switch workspace" },
			{ "<localleader>oi", "<cmd>Obsidian template<cr>",        desc = "Obsidian: Insert template" },
			{ "<localleader>oo", "<cmd>Obsidian open<cr>",            desc = "Obsidian: Open in Obsidian app" },

			-- visual mode
			{ "<localleader>ol", ":'<,'>Obsidian link<cr>",          desc = "Obsidian: Link selection",   mode = "v" },
			{ "<localleader>on", ":'<,'>Obsidian link_new<cr>",      desc = "Obsidian: Link to new note", mode = "v" },
			{ "<localleader>oe", ":'<,'>Obsidian extract_note<cr>",  desc = "Obsidian: Extract to note",  mode = "v" },

			-- buffer-local overrides for vault markdown files
			{ "gf", "<cmd>Obsidian follow_link<cr>", desc = "Obsidian: Follow link" },
		},
	},
}
