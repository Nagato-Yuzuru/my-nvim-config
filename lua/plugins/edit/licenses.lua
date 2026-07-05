-- lua/plugins/edit/licenses.lua
-- License headers + LICENSE-file generation (GR3YH4TT3R93/licenses.nvim).
--
-- nvim-only, no .ideavimrc counterpart: JetBrains handles this through
-- Copyright profiles configured in settings, not a vim-mappable IDE action,
-- so there is nothing to mirror and no keymaps here (see the parity map in
-- CLAUDE.md). The four :License* commands are the whole interface, and the
-- plugin lazy-loads on them.
--
-- No default `license` id by choice — pass the SPDX id explicitly. We override
-- the plugin's :LicenseInsert (see the config function) so that fetching is
-- lazy/invisible: an id the plugin doesn't have locally is downloaded from
-- spdx.org and then inserted, in one command, instead of the stock two-step
-- (:LicenseFetch then :LicenseInsert).
--   :LicenseInsert <Tab>           complete over bundled + previously-fetched ids
--   :LicenseInsert MIT             local id → insert, no network
--   :LicenseInsert Zlib            unknown id → auto-fetch from spdx.org, then insert
--   :LicenseInsert!                insert even if the buffer already looks licensed
--   :LicenseFetch Apache-2.0       (plugin) pre-download full text (needs curl)
--   :LicenseWrite ./LICENSE MIT    (plugin) write full license text to a file
--   :LicenseUpdate                 (plugin) refresh the year in an existing notice
-- Completion lists only locally-available ids (bundled ~14 + whatever you have
-- fetched before); the full 699-id SPDX index is intentionally never offered.
-- curl (for fetching) is present in this config. The plugin also ships
-- {license}/{SPDX} LuaSnip snippet triggers, but they are NOT wired here: those
-- are Lua-format snippets needing require("luasnip.loaders.from_lua").load(),
-- which nothing calls — this config does not use LuaSnip.
-- :LicenseInsert is the sole entry point, by design.

-- Resolve the copyright identity from `git config` at call time instead of
-- baking it in, so the header always matches git — including a repo-local
-- user.name / user.email override when the edited file lives in such a repo.
-- The plugin has no native git fallback (copyright_holder/email default to
-- nil), so we do it here. git runs from the edited file's directory (falling
-- back to cwd) so a local config is seen; git still returns the global identity
-- when the file isn't in a repo. licenses.nvim resolves these FnStrings via
-- util.get_val and may pass the license id as an arg — we ignore it.
local function git_config(key)
	local dir = vim.fn.expand("%:p:h")
	if dir == "" then
		dir = vim.fn.getcwd()
	end
	local value = vim.fn.system({ "git", "-C", dir, "config", key })
	if vim.v.shell_error ~= 0 then
		vim.notify(("licenses.nvim: `git config %s` failed"):format(key), vim.log.levels.WARN)
		return nil
	end
	return vim.trim(value)
end

return {
	"GR3YH4TT3R93/licenses.nvim",
	cmd = { "LicenseInsert", "LicenseFetch", "LicenseUpdate", "LicenseWrite" },
	-- config (not opts) because we redefine :LicenseInsert *after* setup() creates
	-- it. Same post-setup-mutation reason bookmarks.nvim uses config in this repo.
	config = function()
		local licenses = require("licenses")
		local util = require("licenses.util")

		licenses.setup({
			copyright_holder = function() return git_config("user.name") end,
			email = function() return git_config("user.email") end,
			-- With no default license, remember the id per-buffer after the first
			-- insert so :LicenseUpdate / a re-insert in that buffer don't re-prompt.
			remember_previous_id = true,
			-- Constant width instead of the plugin default (vim.bo.textwidth):
			-- get_text() does `wrap_width - #commentstring`, so a buffer with
			-- textwidth=0 underflows negative, which makes it "wrap" every line
			-- (blank lines included) and crash on table.remove of an empty word
			-- list. A fixed positive width both dodges that and wraps license
			-- paragraphs to a sane column.
			wrap_width = 80,
		})

		-- Insert the header for `id`, reusing the plugin's own get_config/insert.
		-- Mirrors licenses.nvim's original :LicenseInsert callback (get_copyright_info
		-- guard → get_config → scan skip_lines → insert). The skip_lines loop is NOT
		-- optional: the plugin's own default is skip_lines = { "^#!" } and setup()
		-- force-merges on top of that base, so the default survives — insert past a
		-- leading shebang so the header lands *below* it, never above (which would
		-- break the script). skip_lines patterns are matched with Lua string.match
		-- (upstream does the same), and upstream appends a blank separator line when
		-- any line was skipped — replicated here.
		local function do_insert(bufnr, id, bang)
			if not bang and licenses.get_copyright_info(bufnr) then
				vim.notify(
					"licenses.nvim: buffer already has licensing info; use :LicenseInsert! to insert anyway",
					vim.log.levels.WARN
				)
				return
			end
			local config = licenses.get_config(bufnr, { license = id })
			local lnum = 0
			local last_lnum = vim.fn.line("$")
			while lnum < last_lnum do
				local line = vim.fn.getline(lnum + 1)
				local skip = false
				for _, pat in ipairs(config.skip_lines or {}) do
					if line:match(pat) then
						skip = true
						break
					end
				end
				if not skip then
					break
				end
				lnum = lnum + 1
				assert(lnum < 50, "licenses.nvim: skip_lines skipped >=50 lines, assuming infinite loop")
			end
			local err = licenses.insert(bufnr, lnum, config)
			if err then
				vim.notify("licenses.nvim: " .. err, vim.log.levels.ERROR)
			elseif lnum ~= 0 then
				vim.fn.appendbufline(bufnr, lnum, "")
			end
		end

		local function is_local(id)
			return util.get_file("header/" .. id .. ".txt") or util.get_file("text/" .. id .. ".txt")
		end

		-- Make fetch lazy/invisible: an id not available locally (bundled or
		-- previously cached) is downloaded from spdx.org, then inserted — one
		-- :LicenseInsert does both. We poll for the cached file rather than insert
		-- from fetch()'s callback, because upstream invokes that callback ONLY on
		-- failure: its success path writes the cache and notifies but never calls
		-- back (licenses/fetch.lua). vim.wait pumps the loop so the async download
		-- lands; it blocks briefly (typically <1s) — fine for a rare, deliberate
		-- action. bufnr is captured by the caller so the insert targets the right
		-- buffer.
		local function ensure_then_insert(bufnr, id, bang)
			if is_local(id) then
				do_insert(bufnr, id, bang)
				return
			end
			local fetch_err
			licenses.fetch(id, function(err) fetch_err = err or false end)
			vim.wait(10000, function() return fetch_err ~= nil or is_local(id) end)
			if is_local(id) then
				do_insert(bufnr, id, bang)
			elseif fetch_err then
				vim.notify("licenses.nvim fetch: " .. tostring(fetch_err), vim.log.levels.ERROR)
			else
				vim.notify("licenses.nvim: fetch timed out for `" .. id .. "`", vim.log.levels.WARN)
			end
		end

		-- Override the plugin's :LicenseInsert to add the lazy auto-fetch. lazy
		-- re-runs the triggering command after load, so this override (not the
		-- setup()-created one above) is what actually executes.
		vim.api.nvim_create_user_command("LicenseInsert", function(opts)
			local bufnr = vim.api.nvim_get_current_buf()
			local id = opts.fargs[1]
			if not id then
				vim.notify(
					"LicenseInsert: pass an SPDX id (<Tab> completes bundled ones, e.g. MIT)",
					vim.log.levels.WARN
				)
				return
			end
			ensure_then_insert(bufnr, id, opts.bang)
		end, {
			nargs = "?",
			bang = true,
			bar = true,
			-- bundled + already-cached only; the 699-id index is never listed.
			complete = function() return util.get_available_licenses() end,
			desc = "Insert license header (bundled ids complete; unknown ids auto-fetch from spdx.org)",
		})
	end,
}
