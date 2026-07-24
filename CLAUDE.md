# CLAUDE.md

Personal Neovim config: lazy.nvim, all-Lua, Neovim 0.11+ (native
`vim.lsp.enable()` + top-level `lsp/`).

> CLAUDE.md holds only what a code comment can't:
> (1) cross-file constraints, (2) entry-point facts you need before
> deciding which file to open, (3) forbidding rules / retired designs
> with no code home. Per-construct rationale lives next to the construct
> — when a bullet below names a file, the full story is in that file's
> header comment; don't duplicate it here.

## Core Principle: Cross-editor Parity

The editing experience in Neovim and JetBrains (via IdeaVim) must stay
consistent — the user works daily in both, and muscle memory must
transfer. `.ideavimrc` is symlinked to `~/.ideavimrc`, so editing it in
this repo affects every JetBrains IDE on the machine.

When changing a keymap / plugin / workflow on one side, **mirror it on
the other** if an IDE Action equivalent exists; if not, leave a comment
on the side that lacks it explaining why. Asymmetries are allowed when
Neovim has genuinely more capability (Flash Treesitter, multi-list
bookmarks) — document them as a comment block in the relevant
`.ideavimrc` section so both sides share the same source of truth for
what's bound where.

### Parity map (.ideavimrc section ↔ nvim file)

| `.ideavimrc` section                                        | Neovim counterpart                                                 |
| ----------------------------------------------------------- | ------------------------------------------------------------------ |
| Leader + clipboard + `J`/`K` visual move + `<C-x>` handling | `lua/core/keymaps.lua`                                             |
| easymotion `<leader><leader>*`                              | `lua/plugins/edit/motion.lua` (flash.nvim)                         |
| `set peekaboo` (`"` / `@` / `<C-r>` register preview)       | `lua/plugins/edit/registers.lua` (junegunn/vim-peekaboo)           |
| `set quickscope` + `g:qs_highlight_on_keys` (lazy f/F/t/T hints) | `lua/plugins/edit/eyeliner.lua` (jinh0/eyeliner.nvim, `highlight_on_key=true`) — owns f/F/t/T; flash `modes.char` disabled to avoid shadowing |
| multi-cursor `<A-n>`/`<A-p>`/`<A-x>`                        | `lua/plugins/edit/multi.lua`                                       |
| Syntax text objects + bracket motions (`af/if`, `ai/ii`, `al/il`, `an/in`, `]f/[f`, …) — "Syntax-aware navigation & editing" section | `lua/plugins/edit/textobjects.lua` (nvim-treesitter-textobjects). IdeaVim side = built-ins + a shrunken AnyObject; **`set targets` and `set textobj-indent` are forbidden as of IdeaVim 2.44** (key-space / forced-mapping conflicts; the `.ideavimrc` ⛔ notes state the unblock conditions — recheck on upgrade, don't treat as permanent). Key-ownership table, forbidding rationale, and the extension-init ordering facts live in the `.ideavimrc` sections — read them, don't re-derive |
| Refactor `<leader>r*`                                       | LSP keymaps in `lua/core/lsp.lua` (`LspAttach`) + `lua/plugins/edit/refactoring.lua` (treesitter extract) + inc-rename for `<leader>rn` |
| Core navigation `g*` (`gd`/`gD`/`gi`/`gr`)                  | LSP keymaps in `lua/core/lsp.lua` (`LspAttach`) + `lua/plugins/ui/trouble.lua` (`gr`) |
| Preview `gp*` (nvim-only — IDE uses `⌥Space` Quick Def)     | `lua/plugins/lsp/preview.lua` (goto-preview)                       |
| Surround / Unwrap `<leader>g{t,T,u}`                        | `lua/plugins/edit/wrap.lua`（三键位 + deleft.vim spec）; engine/templates in `lua/tools/wrap.lua` |
| Navigation extras `<leader>n*` (no `g*` equivalent), plus `<leader>n{h,j,k,l}` walker hydra (nvim-only) | LSP keymaps in `lua/core/lsp.lua` (`LspAttach`) + `lua/plugins/ui/aerial.lua` + `lua/plugins/ui/hydra.lua` (bindings; treewalker plugin spec is `lua/plugins/edit/treewalker.lua`) |
| Search `<leader>s*` (nvim-only — IDE uses Search Everywhere) | `lua/plugins/ui/snacks.lua` (bulk), plus `<leader>sr` `edit/rip-substitute.lua`, `<leader>sR` `edit/grug-far.lua`, `<leader>sm` `edit/marks.lua` |
| Views `<leader>v*`                                          | Spread across `lua/plugins/{ui,git,runtime,edit}/` — `grep '<leader>v'` |
| Git `<localleader>g*` + `]c/[c` hunk nav, `<leader>v{D,H}` diff/history | `lua/plugins/git/{gitsigns,diffview,conflict}.lua`. IdeaVim side mirrors per-key (`,gp/,gb/,gr/,gd/,gx`); nvim-only: `,gs` hunk-stage toggle, `,gB` gutter-base switch, in-buffer conflict ops (`co/ct/cb/c0`, `]x/[x`) — IDE handles those in gutter toolbar / merge dialog. Asymmetry notes live in the `.ideavimrc` Git section |
| Reformat `<leader>f*`                                       | `lua/plugins/format/conform.lua`                                   |
| Mark / bookmark `<leader>m*`, `<leader>M`                   | `lua/plugins/edit/marks.lua`                                       |
| Debug `<leader>D` / `<leader>d*` / `<leader>vd` (static), `<localleader>*` (session-scoped) | `lua/plugins/runtime/dap.lua`                                      |
| Run / Task `<leader>vr`, `<leader>o*` (nvim-only)           | `lua/plugins/runtime/overseer.lua`                                 |
| Test `<leader>t*` (nvim-only)                               | `lua/plugins/runtime/neotest.lua`                                  |
| Markdown `<localleader>m*` (nvim-only — IDE has built-in editor+preview split) | `lua/plugins/lang/markdown.lua` (render-markdown toggles + live-preview `,mb` browser preview) |
| AI / Claude Code `<leader>a*` (nvim-only — IDE uses the official Claude Code plugin's tool window) | `lua/plugins/ai/claudecode.lua` (coder/claudecode.nvim, `none` mode + tmux `/ide`) |
| Terminal asymmetry 注释块（`<C-x>\`` toggle + `<C-]>` 逃生舱，nvim-only — JetBrains 终端非 IdeaVim 辖区） | `lua/plugins/ui/toggleterm.lua`（裸 shell 设计）+ `lua/plugins/ui/flatten.lua`（防套娃） |

## Architecture (entry-point facts)

The layout is self-describing — see `ls`. The non-obvious bits:

- **Native LSP only** — never `lspconfig[server].setup()`. Per-server
  configs go in `lsp/<server>.lua`, enabled from `lua/core/lsp.lua`.
- **DAP per-adapter** (mirrors `lsp/`): **add a debugger by dropping a
  file in `dap/<adapter>.lua`** (wired by `lua/core/dap.lua`) — never
  grow `lua/plugins/runtime/dap.lua`.
- **LSP keymaps live in `LspAttach`** (in `lua/core/lsp.lua`), not in
  `core/keymaps.lua` — so they're scoped to clients that actually
  attached. `gr` is owned by `lua/plugins/ui/trouble.lua`.
- **Mason auto-install**: `lua/tools/mason_ensure.lua` is SSOT for **LSP
  + formatters + linters** (conform / nvim-lint pull from it via
  getters). DAP installs separately via `mason-registry` from
  `lua/core/dap.lua` (not `mason-nvim-dap`). Both skip under `CI=true` /
  `NO_AUTO_INSTALL=1` — init.lua's firenvim branch relies on that env
  contract.
- **Picker is Snacks.nvim** (no Telescope for picking). telescope.nvim
  is present only as gitignore.nvim's multi-select dependency
  (`lua/plugins/git/gitignore.lua`) — don't add new telescope consumers.
- **Go IDEA-style auto-import** (bare `Builder`→`strings.Builder`+import)
  is **go-deep.nvim**, not gopls (golang/go#58291). Cross-file wiring:
  plugin + `vim.g.go_deep` SSOT in `lua/plugins/completion/go_deep.lua`;
  blink source/provider registered in
  `lua/plugins/completion/blink.lua`. **Tracks `master` (unpinned)** —
  re-review on `:Lazy update`. Neovim-only — GoLand has it natively.
- **golangci-lint quickfixes are custom-wired** (upstream's nvim-lint
  adapter drops `SuggestedFixes` — it is **never required**; the linter
  is self-owned in `lua/plugins/lint/nvim-lint.lua`). Cross-file flow:
  parser in `lua/tools/golangci_fix.lua` stashes fixes in diagnostic
  `user_data`; in-process LSP `lsp/golangci_fix.lua` (enabled in
  `lua/core/lsp.lua`) serves them as code actions on the normal
  `<leader>ca` / `<A-CR>` flow.
- **Claude Code integration is coder/claudecode.nvim in `none` mode**
  (`lua/plugins/ai/claudecode.lua`): nvim hosts only the WebSocket IDE
  server; the `claude` CLI runs in a tmux pane and attaches via `/ide`.
  Protocol is reverse-engineered upstream → **pinned by `commit`**,
  re-review on `:Lazy update` (same policy as go-deep.nvim). Neovim-only
  — JetBrains has the official plugin.
- **Plugin domains are bisection units**: each domain under
  `lua/plugins/` is imported separately in `init.lua`, so any one can be
  commented out to isolate breakage. Two exceptions:
  `plugins/treesitter.lua` is a single file, and `plugins/schemas/` is
  not in the lazy spec at all — `init.lua` requires
  `plugins.schemas.picker` directly at the end, which lazily requires
  `cloud_native_schema` on `:SchemaSelect`.

## Forbidding rules / retired designs

These constrain code that *isn't there*; comments have nowhere to live.

- **`<leader>n{d,D,i,u}` are retired.** Don't re-introduce them as
  aliases for `g*`. `<leader>n*` only survives for jumps with **no**
  `g*` counterpart: `<leader>nb` supertypes; IdeaVim-only `<leader>nt`
  GotoTest / `<leader>nf` FindInPath; `<leader>ns` structure popup.
- **`<leader>nt` (GotoTest) is IdeaVim-only.** Neotest is a runner, not
  a navigator — don't invent a heuristic. Use `<leader>tt` or language
  tooling (`:GoAlt`).
- **`<C-x>` is a vim-layer chord prefix on both sides.** Both sides
  remap Vim's default decrement to `<C-S-A>`. nvim hosts its chords in
  `lua/core/keymaps.lua` + bufferline; the IDEA side hosts them as
  `.ideavimrc` nmap/imap. The IntelliJ IDE keymap ("Emacs Custom") must
  keep **zero** `C-x` shortcuts: any IDE-keymap `C-x` chord captures the
  first keystroke IDE-wide and steals the whole `C-x` prefix from the
  Terminal tool window's shell (emacs `C-x C-c`, zsh `C-x C-e`). New
  `<C-x>*` bindings go into `.ideavimrc`, never into the IDE keymap.
  (IntelliJ IDEA's "Emacs Custom.xml" is the canonical copy; the other
  JetBrains products carry verbatim copies of it — edit IDEA's, then
  `cp` to the rest.)
- **DAP keymaps split into static `<leader>d*` and session-only
  `<localleader>*`** (= `,`). Static binds at startup; session binds
  attach/detach via `dap.listeners.on_session` (see
  `lua/plugins/runtime/dap.lua`). The `actions` local there is SSOT —
  don't duplicate-bind those actions under `<leader>d*`. F-keys
  intentionally unused (leader/localleader stays in Vim grammar, works
  across keyboard layouts).

## Conventions

- **Tests (mini.test)**: self-written logic (`lua/tools/*`, `core/lsp`
  repair) has child-process specs in `tests/test_*.lua`. Run:
  `nvim --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()"`
  (same command as CI; `tests/minimal_init.lua` self-bootstraps `.deps/`,
  pins follow lazy-lock.json). Gate is CI only
  (`.github/workflows/test.yml`, which also runs `stylua --check` and
  `selene`) — no local hooks, by design. selene is deliberately NOT wired
  into nvim-lint (lua_ls already lints live; see selene.toml).
- Non-plugin config in `lua/core/` only.
- Prefer `opts` over `config` functions.
- Lazy-load with `event` / `ft` / `cmd` / `keys`.
- Always set `desc` on keymaps — which-key relies on it.
- **Before merging any keymap/plugin change, re-check the parity map.**
