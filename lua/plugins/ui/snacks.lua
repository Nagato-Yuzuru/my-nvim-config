-- z* fold-style controls for snacks.explorer.
-- The cursor's "fold scope" is its directory: the dir itself when the cursor
-- is on a directory, or the containing dir when it's on a file (matching the
-- semantics of `explorer_close`).
local function fold_target(picker, item)
	local Tree = require("snacks.explorer.tree")
	if not item then
		return Tree:find(picker:cwd()), picker:cwd()
	end
	local path = item.dir and item.file or vim.fs.dirname(item.file)
	return Tree:find(path), path
end

local function open_recursive(node)
	local Tree = require("snacks.explorer.tree")
	if not node or not node.dir then
		return
	end
	node.open = true
	if not node.expanded then
		Tree:expand(node)
	end
	for _, child in pairs(node.children) do
		if child.dir then
			open_recursive(child)
		end
	end
end

local function close_recursive(node)
	if not node or not node.dir then
		return
	end
	node.open = false
	node.expanded = false
	for _, child in pairs(node.children) do
		if child.dir then
			close_recursive(child)
		end
	end
end

local function fold_refresh(picker)
	require("snacks.explorer.actions").update(picker, { refresh = true })
end

return {
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		opts = {
			-- Friendly help popup: rounded centered float with a title, instead of
			-- the default dense grid docked at the bottom.
			styles = {
				help = {
					position = "float",
					backdrop = false,
					border = "rounded",
					title = " Keymaps — press ? to close ",
					title_pos = "center",
					row = 0.15,
					col = 0.5,
					width = 0.6,
				},
			},
			picker = {
				enabled = true,
				-- Replace vim.ui.select with Snacks' picker system-wide.
				-- Auto-benefits any plugin that prompts via vim.ui.select
				-- (e.g. LintaoAmons/bookmarks.nvim's list/delete prompts).
				ui_select = true,
				layout = { preset = "default" },
				-- Wider columns → fewer keys per row, each entry gets breathing room.
				actions = {
					toggle_help_input = function(p)
						p.input.win:toggle_help({ col_width = 45, key_width = 14 })
					end,
					toggle_help_list = function(p)
						p.list.win:toggle_help({ col_width = 45, key_width = 14 })
					end,
				},
				sources = {
					explorer = {
						-- Vim fold-style level controls for the directory tree.
						-- z[oc] single dir · z[OC] recursive · z[RM] whole tree · z[aA] toggle.
						actions = {
							fold_open = function(picker, item)
								local node = fold_target(picker, item)
								if node and node.dir then
									require("snacks.explorer.tree"):open(node.path)
									fold_refresh(picker)
								end
							end,
							fold_open_recursive = function(picker, item)
								local node = fold_target(picker, item)
								if node and node.dir then
									open_recursive(node)
									fold_refresh(picker)
								end
							end,
							fold_close_recursive = function(picker, item)
								local node = fold_target(picker, item)
								if node and node.dir then
									close_recursive(node)
									fold_refresh(picker)
								end
							end,
							fold_toggle = function(picker, item)
								local node, path = fold_target(picker, item)
								if node and node.dir then
									require("snacks.explorer.tree"):toggle(path)
									fold_refresh(picker)
								end
							end,
							fold_toggle_recursive = function(picker, item)
								local node = fold_target(picker, item)
								if node and node.dir then
									if node.open then
										close_recursive(node)
									else
										open_recursive(node)
									end
									fold_refresh(picker)
								end
							end,
							fold_open_all = function(picker)
								local Tree = require("snacks.explorer.tree")
								open_recursive(Tree:find(picker:cwd()))
								fold_refresh(picker)
							end,
						},
						win = {
							list = {
								keys = {
									["]c"] = "explorer_git_next",
									["[c"] = "explorer_git_prev",
									["zo"] = "fold_open",
									["zc"] = "explorer_close",
									["zO"] = "fold_open_recursive",
									["zC"] = "fold_close_recursive",
									["za"] = "fold_toggle",
									["zA"] = "fold_toggle_recursive",
									["zR"] = "fold_open_all",
									["zM"] = "explorer_close_all",
								},
							},
						},
					},
				},
			},
			explorer = {
				enabled = true,
				replace_netrw = true, -- hijack directory opens (was Neo-tree hijack_netrw)
			},
			dashboard = { enabled = true }, -- 启动页
			notifier = { enabled = true },
		},
		keys = {
			{
				"<leader>vp",
				function()
					Snacks.explorer()
				end,
				desc = "Explorer",
			},
			{
				"<leader>,",
				function()
					Snacks.picker.buffers()
				end,
				desc = "Buffers",
			},
			{
				"<leader>/",
				function()
					Snacks.picker.grep()
				end,
				desc = "Grep",
			},
			{
				"<leader>ss",
				function()
					Snacks.picker.lsp_workspace_symbols()
				end,
				desc = "Workspace Symbols",
			},
			{
				"<leader>sc",
				function()
					Snacks.picker.commands()
				end,
				desc = "Commands",
			},
			{
				"<leader>sk",
				function()
					Snacks.picker.keymaps()
				end,
				desc = "Keymaps",
			},
			{
				"<leader>vn",
				function()
					Snacks.notifier.show_history()
				end,
				desc = "Notification History",
			},
			{
				"<localleader>G",
				function()
					Snacks.lazygit()
				end,
				desc = "Git: Lazygit",
			},
			{
				"<localleader>gl",
				function()
					Snacks.lazygit.log()
				end,
				desc = "Git: Log (Lazygit)",
			},
		},
	},
}
