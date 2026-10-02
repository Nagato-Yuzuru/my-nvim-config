# CLAUDE.md

Personal Neovim config: lazy.nvim, all-Lua, Neovim 0.12+ (native
`vim.lsp.enable()` + top-level `lsp/`).

> CLAUDE.md holds only what a code comment can't: cross-file
> constraints, entry-point facts needed before choosing which file to
> open, and forbidding rules / retired designs with no code home. When a
> bullet names a file, the full story is in that file's header comment.

## Core Principle: Cross-editor Parity

The editing experience in Neovim and JetBrains (via IdeaVim) must stay
consistent — the user works daily in both, and muscle memory must
transfer. `.ideavimrc` is symlinked to `~/.ideavimrc`, so editing it in
this repo affects every JetBrains IDE on the machine.

When changing a keymap / plugin / workflow on one side, **mirror it on
the other** if an IDE Action equivalent exists; if not, leave a comment
on the side that lacks it explaining why. Asymmetries are allowed when
Neovim has genuinely more capability — document them as a comment block
in the relevant `.ideavimrc` section, which is the source of truth for
what's bound where. Re-check the map below before merging any
keymap/plugin change.

### Parity map (.ideavimrc section ↔ nvim file)

| `.ideavimrc` section                                                                                        | Neovim counterpart                                                                                                                                                                                       |
| ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Leader + clipboard + `J`/`K` visual move + `<C-x>` handling                                                 | `lua/core/keymaps.lua`                                                                                                                                                                                   |
| easymotion `<leader><leader>*`                                                                              | `lua/plugins/edit/motion.lua` (flash.nvim)                                                                                                                                                               |
| `set peekaboo`                                                                                              | `lua/plugins/edit/registers.lua` (vim-peekaboo)                                                                                                                                                          |
| `set quickscope` (f/F/t/T hints)                                                                            | `lua/plugins/edit/eyeliner.lua` — owns f/F/t/T; flash char mode is off                                                                                                                                   |
| multi-cursor `<A-n>`/`<A-p>`/`<A-x>`                                                                        | `lua/plugins/edit/multi.lua`                                                                                                                                                                             |
| "Syntax-aware navigation & editing" (text objects + `]`/`[` bracket motions)                                | `lua/plugins/edit/textobjects.lua`. `set targets` / `set textobj-indent` are forbidden as of IdeaVim 2.46 — the `.ideavimrc` `FORBIDDEN:` notes carry the unblock conditions; recheck on IdeaVim upgrade |
| Refactor `<leader>r*`                                                                                       | `lua/core/lsp.lua` (`LspAttach`) + `lua/plugins/edit/refactoring.lua` + `lua/plugins/lsp/inc-rename.lua`                                                                                                 |
| Core navigation `g*`                                                                                        | `lua/core/lsp.lua` (`LspAttach`); `gr` is `lua/plugins/ui/trouble.lua`                                                                                                                                   |
| Preview `gp*` (nvim-only — IDE uses `⌥Space` Quick Def)                                                     | `lua/plugins/lsp/preview.lua`                                                                                                                                                                            |
| Generate `<leader>G` + `<leader>g*` concept keys (IdeaVim-only)                                             | `<leader>ca` in `lua/core/lsp.lua` — the code-action surface is the shared equivalent, not a gap to close. The `.ideavimrc` §4 comment settles the per-filetype `BufEnter` dispatch facts                |
| Surround / Unwrap `<leader>g{t,T,u}`                                                                        | `lua/plugins/edit/wrap.lua`; engine in `lua/tools/wrap.lua`                                                                                                                                              |
| Navigation extras `<leader>n*`                                                                              | `lua/core/lsp.lua` + `lua/plugins/ui/aerial.lua` + `lua/plugins/ui/hydra.lua` (`<leader>n{h,j,k,l}` walker, nvim-only)                                                                                   |
| Search `<leader>s*` (nvim-only — IDE uses Search Everywhere)                                                | `lua/plugins/ui/snacks.lua` + a few `lua/plugins/edit/*` — `grep '<leader>s'`                                                                                                                            |
| Views `<leader>v*`                                                                                          | spread across `lua/plugins/` — `grep '<leader>v'`                                                                                                                                                        |
| Git `<localleader>g*`, `]c/[c`, `<leader>v{D,H}`                                                            | `lua/plugins/git/{gitsigns,diffview,conflict}.lua`; asymmetry notes in the `.ideavimrc` Git section                                                                                                      |
| Reformat `<leader>f*`                                                                                       | `lua/plugins/format/conform.lua`                                                                                                                                                                         |
| Shell filter `!` (IdeaVim native)                                                                           | `lua/plugins/edit/bang.lua` (our own bang.nvim; `g!` family is nvim-only)                                                                                                                                |
| Mark / bookmark `<leader>m*`, `<leader>M`                                                                   | `lua/plugins/edit/marks.lua`                                                                                                                                                                             |
| Debug `<leader>d*` / `<leader>D` / `<leader>vd`, session `<localleader>*`, stop-time step hydra (nvim-only) | `lua/plugins/runtime/dap.lua` + `lua/tools/debug_hydra.lua`                                                                                                                                              |
| Run / Task `<leader>vr`, `<leader>o*` (nvim-only)                                                           | `lua/plugins/runtime/overseer.lua`                                                                                                                                                                       |
| Test `<leader>t*` (nvim-only)                                                                               | `lua/plugins/runtime/neotest.lua`                                                                                                                                                                        |
| Markdown `<localleader>m*` (nvim-only)                                                                      | `lua/plugins/lang/markdown.lua`                                                                                                                                                                          |
| AI `<leader>a*` (nvim-only — IDE has the official Claude Code plugin)                                       | `lua/plugins/ai/claudecode.lua`                                                                                                                                                                          |
| Terminal asymmetry block (nvim-only)                                                                        | `lua/plugins/ui/toggleterm.lua` + `lua/plugins/ui/flatten.lua`                                                                                                                                           |

## Architecture (entry-point facts)

- **Native LSP only** — never `lspconfig[server].setup()`. Per-server
  configs go in `lsp/<server>.lua`. No hand-written enablement/probe
  branches: `lua/core/lsp.lua` enables the union of two declarative
  inventories (next bullet).
- **Install plane vs language plane.** `lua/tools/mason_ensure.lua` is
  the SSOT for which LSP/formatter/linter binaries Mason manages.
  Language _behavior_ — ft detection, PATH-probed LSP enablement,
  in-process servers — is registered top-level by `plugins/lang/<x>.lua`
  via `lua/tools/lang_registry.lua`. Adding or changing a language:
  see "Language toolchain changes" below.
- **Auto-install contract**: both installers skip under
  `NO_AUTO_INSTALL=1`; init.lua's firenvim branch depends on it.
- **LSP keymaps live in `LspAttach`** (`lua/core/lsp.lua`), not
  `core/keymaps.lua`.
- **Picker is Snacks.nvim.** telescope.nvim exists only as
  gitignore.nvim's dependency — new pickers go through Snacks.
- **Commit-pinned / branch-tracking plugins to re-review on
  `:Lazy update`**: go-deep.nvim (`lua/plugins/completion/go_deep.lua`,
  tracks `master`; its blink provider lives in `blink.lua`) and
  claudecode.nvim (`lua/plugins/ai/claudecode.lua`, pinned `commit`,
  reverse-engineered protocol).
- **golangci-lint quickfixes are custom-wired**: parser
  `lua/tools/golangci_fix.lua` → in-process LSP `lsp/golangci_fix.lua`
  (enabled from `plugins/lang/go.lua`) → code actions + a
  `source.fixAll.golangci` that `<leader>ff` applies. The linter is
  self-owned in `lua/plugins/lint/nvim-lint.lua`; fixes go through that
  code-action path, never `golangci-lint run --fix` (no stdin mode,
  rewrites sibling files).
- **Treesitter query overrides** live in `queries/<lang>/` and
  `after/queries/<lang>/`, with a `; extends` header (union with
  upstream). Text-object keys keep one meaning across languages: extend
  a language by adding captures, not keys.
- `plugins/schemas/` is outside the lazy spec — `init.lua` requires
  `plugins.schemas.picker` directly.

## Language toolchain changes

Adding or changing a language touches several files; walk every row
and touch the ones that apply:

| Concern                                                | Where                                                                                                                                                                                |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Mason-installable LSP                                  | `LSP_TOOLS` in `lua/tools/mason_ensure.lua` + `lsp/<server>.lua`                                                                                                                     |
| Mason-installable non-LSP tool                         | `TOOL_MAP` + `TOOL_INSTALLS_BY_FT` (install intent, whoever runs it — formatter, or an LSP's backend like bashls → shellcheck) or `LINTERS_BY_FT` (nvim-lint runs it; installed too) |
| Which formatter runs                                   | `lua/plugins/format/conform.lua`                                                                                                                                                     |
| Linter wiring, path/content-gated linters              | `lua/plugins/lint/nvim-lint.lua`                                                                                                                                                     |
| Non-Mason tool (mise / rustup / system / `go install`) | probe-gated `lsp` entry in `plugins/lang/<x>.lua`; missing binaries get a notify-the-command advisor (`lua/tools/<x>_toolchain.lua`) — global installs stay manual                   |
| ft detection                                           | `plugins/lang/<x>.lua` via `lang_registry`                                                                                                                                           |
| Parser                                                 | `plugins/treesitter.lua`                                                                                                                                                             |
| Debugger                                               | `dap/<adapter>.lua` (wired and mason-installed by `lua/core/dap.lua`); `lua/plugins/runtime/dap.lua` holds keymaps/UI only                                                           |

**Install tier.** A language is either _daily_ (toolchain installed at
startup) or _on-demand_ (installed on first open of its ft, LSP
re-attached automatically). New languages are on-demand; tier
membership is the user's call — promote a language by adding its fts
to `DAILY_FTS`. An LSP's tier derives from its `filetypes`, so an
`external_owner` entry declares `filetypes` itself. The daily-tier case
in `tests/test_mason_ensure.lua` asserts concrete package names — update
it when the daily set changes.

## Forbidding rules / retired designs

- **`<leader>n{d,D,i,u}` are retired** — `g*` owns those jumps.
  `<leader>n*` holds only jumps with no `g*` counterpart.
- **`<leader>nt` (GotoTest) is IdeaVim-only.** Neotest is a runner, not
  a navigator — use `<leader>tt` or language tooling (`:GoAlt`).
- **`<C-x>` is a vim-layer chord prefix on both sides** (decrement
  moves to `<C-S-A>`). New `<C-x>*` bindings go into `.ideavimrc`; the
  IntelliJ IDE keymap ("Emacs Custom") keeps **zero** `C-x` shortcuts,
  since any IDE-keymap `C-x` chord steals the prefix from the Terminal
  tool window's shell. IDEA's "Emacs Custom.xml" is canonical; other
  JetBrains products carry verbatim `cp`s of it.
- **DAP keymaps: static `<leader>d*` vs session-only `<localleader>*`.**
  The `actions` local in `lua/plugins/runtime/dap.lua` is SSOT — bind
  each action once. F-keys stay unused. The stop-time step hydra
  (`lua/tools/debug_hydra.lua`) is the one sanctioned alias surface;
  keep its heads in sync with `actions`.
- **JS/TS testing & debugging are retired (2026-08-20)**: no neotest
  adapter, no `dap/js-debug.lua` — JS test frameworks are too
  fragmented for one adapter, and JetBrains covers the domain. If node
  debugging is ever needed, restore `dap/js-debug.lua` from git history.
- **Mechanized parity checking is retired (2026-08-15)**: a CI keymap
  presence diff was tried and rejected — asymmetry is the norm, so its
  allowlist outgrew the aligned surface. Parity stays a review-time
  judgment; keep the prose map.

## Conventions

- Self-written logic (`lua/tools/*` and the like) ships with a mini.test
  spec in `tests/`.
- Non-plugin config goes in `lua/core/`; reusable logic in `lua/tools/`.
- Always set `desc` on keymaps — which-key relies on it.
