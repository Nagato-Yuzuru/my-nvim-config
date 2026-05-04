-- lua/plugins/edit/marks.lua
-- Marks and bookmarks layer, aligned with the IdeaVim side (.ideavimrc "7) Mark").
--
-- Two layers with different purposes:
--
-- 1) marks.nvim — visualizes native Vim marks (mA-mZ, ma-mz) in the signcolumn.
--    Storage: Neovim shada. Persistent across sessions. IdeaVim has its own
--    native mark support, so no mirroring is needed on the IdeaVim side.
--
--    Key prefix: `m` (marks.nvim default).
--      m{a-zA-Z}   set letter mark (native)
--      m,          set next available letter mark
--      m;          toggle next available mark on current line
--      m]  m[      next / prev mark
--      m:          preview mark list
--      dm-         delete all marks on current line
--      dm<space>   delete all marks in buffer
--      dm{a-zA-Z}  delete a specific letter mark
--
-- 2) LintaoAmons/bookmarks.nvim — annotated, multi-list persistent bookmarks.
--    Storage: SQLite via kkharji/sqlite.lua. A separate namespace from native
--    marks; unlimited count, each with name + description, organized into
--    user-defined lists.
--
--    Mirrors .ideavimrc "7) Mark" section:
--      <leader>M   :BookmarksTree        master / tree view (IdeaVim: Bookmarks panel)
--      <leader>vm  :BookmarksTree        alias of <leader>M (IdeaVim parity:
--                                        ActivateBookmarksToolWindow lives at vm there;
--                                        master singleton stays canonical, this is
--                                        the cross-editor convenience alias)
--      <leader>mm  :BookmarksMark        (IdeaVim: ToggleBookmark)
--      <leader>mM  :BookmarksDesc        (IdeaVim: ToggleBookmarkWithMnemonic)
--      <leader>mn  :BookmarksGotoNext    (IdeaVim: GotoNextBookmarkInEditor)
--      <leader>mN  :BookmarksGotoPrev    (IdeaVim: GotoPreviousBookmark)
--
--    Search namespace (search by keyword, picker UI):
--      <leader>sm  :BookmarksGoto        fuzzy picker over all bookmarks
--                                        (search intent → s* namespace; backed
--                                         by Telescope due to LintaoAmons hard
--                                         dep — see notes below)
--
--    nvim-only extras (no IdeaVim equivalent; documented in .ideavimrc):
--      <leader>ml  :BookmarksLists       switch active bookmark list
--      <leader>ma  :BookmarksCommands    command palette (bookmarks)
--      <leader>mg  :BookmarksGrep        grep inside bookmarked files
--
-- ── Why telescope is a dependency ───────────────────────────────────────────
--
-- LintaoAmons/bookmarks.nvim hard-requires telescope at module load time.
-- Its plugin/bookmarks.lua calls require("bookmarks"), which transitively
-- loads picker/actions.lua, which unconditionally calls
-- require("telescope.actions.state"). So telescope is needed even for
-- commands that don't use the picker (e.g. :BookmarksTree, :BookmarksMark).
-- There is no way to avoid this short of forking the plugin.
--
-- Mitigation: telescope + plenary are declared as dependencies here and
-- stay lazy. They only load when bookmarks.nvim loads, which itself only
-- loads on the `keys` / `cmd` triggers. The rest of this config keeps using
-- Snacks for its primary pickers (<leader>, / <leader>/); telescope is
-- invisible in the day-to-day workflow and only surfaces when you hit a
-- bookmark command.
--
-- Side benefit: since telescope is present anyway, `<leader>sm` is bound
-- to :BookmarksGoto for a proper fuzzy picker over bookmark descriptions.
-- Snacks' ui_select integration (enabled in plugins/ui/snacks.lua) still
-- routes LintaoAmons' internal vim.ui.select prompts (list switcher,
-- delete confirmations) through Snacks for a consistent UX on the
-- non-fuzzy-picker paths.

return {
	-- ── 1) marks.nvim: native mark visualization ────────────────────────────
	{
		"chentoast/marks.nvim",
		event = "VeryLazy",
		opts = {
			default_mappings = true,
			-- Only visualize letter marks; skip the noisy built-ins like
			-- . < > ^ to keep the signcolumn clean.
			builtin_marks = {},
			cyclic = true,
			force_write_shada = false,
			refresh_interval = 250,
			-- bookmarks.nvim below uses a higher sign_priority so annotated
			-- bookmarks win a same-line collision against native letter marks.
			sign_priority = 10,
			excluded_filetypes = {
				"snacks_picker_list",
				"trouble",
				"toggleterm",
				"lazy",
				"mason",
				"help",
				"qf",
			},
		},
	},

	-- ── 2) LintaoAmons/bookmarks.nvim: annotated multi-list bookmarks ───────
	{
		"LintaoAmons/bookmarks.nvim",
		dependencies = {
			"kkharji/sqlite.lua",
			-- telescope is a HARD dependency of LintaoAmons: plugin/bookmarks.lua
			-- requires("bookmarks") → picker/actions.lua → telescope.actions.state
			-- at load time, so it's needed even for commands that don't use the
			-- picker (e.g. :BookmarksTree, :BookmarksMark). plenary is telescope's
			-- own dep. Both stay lazy: they only load when bookmarks.nvim loads,
			-- which itself only loads on the keys / cmd triggers below.
			"nvim-telescope/telescope.nvim",
			"nvim-lua/plenary.nvim",
		},
		cmd = {
			"BookmarksMark",
			"BookmarksDesc",
			"BookmarksGoto",
			"BookmarksGotoNext",
			"BookmarksGotoPrev",
			"BookmarksLists",
			"BookmarksCommands",
			"BookmarksGrep",
			"BookmarksTree",
			"BookmarksInfo",
		},
		keys = {
			-- Mirrors .ideavimrc "7) Mark" section
			{ "<leader>M", "<cmd>BookmarksTree<cr>", desc = "Bookmark: tree view" },
			-- Alias of <leader>M for IdeaVim parity (ActivateBookmarksToolWindow
			-- is at <leader>vm there). Master singleton remains the canonical entry;
			-- this just removes the cross-editor asymmetry.
			{ "<leader>vm", "<cmd>BookmarksTree<cr>", desc = "Bookmark: tree view (alias of <leader>M)" },
			{ "<leader>mm", "<cmd>BookmarksMark<cr>", desc = "Bookmark: toggle / rename" },
			{ "<leader>mM", "<cmd>BookmarksDesc<cr>", desc = "Bookmark: add description" },
			{ "<leader>mn", "<cmd>BookmarksGotoNext<cr>", desc = "Bookmark: next" },
			{ "<leader>mN", "<cmd>BookmarksGotoPrev<cr>", desc = "Bookmark: prev" },
			-- Search namespace: search bookmarks by keyword (picker intent).
			{ "<leader>sm", "<cmd>BookmarksGoto<cr>", desc = "Search bookmarks (picker)" },
			-- nvim-only extras (no IdeaVim equivalent)
			{ "<leader>ml", "<cmd>BookmarksLists<cr>", desc = "Bookmark: switch list" },
			{ "<leader>ma", "<cmd>BookmarksCommands<cr>", desc = "Bookmark: commands" },
			{ "<leader>mg", "<cmd>BookmarksGrep<cr>", desc = "Bookmark: grep in files" },
		},
		config = function()
			require("bookmarks").setup({})

			-- Post-setup mutation of the merged treeview keymap.
			--
			-- Why post-setup: vim.tbl_deep_extend has no "remove key" semantics,
			-- so passing changes through setup() can only replace values, not
			-- delete entries. Both tree/init.lua (register_local_shortcuts)
			-- and tree/operate.lua (show_help) read vim.g.bookmarks_config
			-- fresh on every invocation, so mutating it here takes effect
			-- on the next :BookmarksTree (both for bindings and `?` help).
			--
			-- Two concerns:
			--   1. Drop the aider integration keys (+, =, -). nvim_aider is
			--      not installed (Claude Code fills that role instead).
			--   2. Add yazi-style hierarchical h/l. Horizontal cursor motion
			--      is meaningless in a tree buffer, so they're repurposed as
			--      level-down / level-up. Mirrors Snacks explorer's h/l bindings
			--      so the two sidebar tree views feel consistent.
			local cfg = vim.g.bookmarks_config
			if cfg and cfg.treeview and cfg.treeview.keymap then
				cfg.treeview.keymap["+"] = nil
				cfg.treeview.keymap["="] = nil
				cfg.treeview.keymap["-"] = nil
				cfg.treeview.keymap["l"] = {
					action = "toggle",
					desc = "Open / expand node (yazi-style)",
				}
				cfg.treeview.keymap["h"] = {
					action = "level_up",
					desc = "Collapse / parent (yazi-style)",
				}
				vim.g.bookmarks_config = cfg
			end
		end,
	},
}
