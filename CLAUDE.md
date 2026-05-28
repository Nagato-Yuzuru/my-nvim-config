# CLAUDE.md

Personal Neovim config: lazy.nvim, all-Lua, Neovim 0.11+ (native
`vim.lsp.enable()` + top-level `lsp/`).

> CLAUDE.md holds only what a code comment can't:
> (1) cross-file constraints, (2) entry-point facts you need before
> deciding which file to open, (3) forbidding rules / retired designs
> with no code home. Per-construct rationale lives next to the construct.

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
| Refactor `<leader>r*`                                       | LSP keymaps in `lua/core/lsp.lua` (`LspAttach`) + `lua/plugins/edit/refactoring.lua` (treesitter extract) + inc-rename for `<leader>rn` |
| Core navigation `g*` (`gd`/`gD`/`gi`/`gr`)                  | LSP keymaps in `lua/core/lsp.lua` (`LspAttach`) + `lua/plugins/ui/trouble.lua` (`gr`) |
| Preview `gp*` (nvim-only — IDE uses `⌥Space` Quick Def)     | `lua/plugins/lsp/preview.lua` (goto-preview)                       |
| Navigation extras `<leader>n*` (no `g*` equivalent), plus `<leader>n{h,j,k,l}` walker hydra (nvim-only) | LSP keymaps in `lua/core/lsp.lua` (`LspAttach`) + `lua/plugins/ui/aerial.lua` + `lua/plugins/ui/hydra.lua` (treewalker) |
| Search `<leader>s*` (nvim-only — IDE uses Search Everywhere) | `lua/plugins/ui/snacks.lua`                                       |
| Views `<leader>v*`                                          | Spread across `lua/plugins/{ui,git,runtime,edit}/` — `grep '<leader>v'` |
| Reformat `<leader>f*`                                       | `lua/plugins/format/conform.lua`                                   |
| Mark / bookmark `<leader>m*`, `<leader>M`                   | `lua/plugins/edit/marks.lua`                                       |
| Debug `<leader>D` / `<leader>d*` / `<leader>vd` (static), `<localleader>*` (session-scoped) | `lua/plugins/runtime/dap.lua`                                      |
| Run / Task `<leader>vr`, `<leader>o*` (nvim-only)           | `lua/plugins/runtime/overseer.lua`                                 |
| Test `<leader>t*` (nvim-only)                               | `lua/plugins/runtime/neotest.lua`                                  |

## Architecture (entry-point facts)

The layout is self-describing — see `ls`. The non-obvious bits:

- **Native LSP only** — never `lspconfig[server].setup()`. Per-server
  configs go in `lsp/<server>.lua`, enabled via `vim.lsp.enable()` from
  `lua/core/lsp.lua`.
- **DAP per-adapter** (mirrors `lsp/`): per-adapter specs in
  `dap/<adapter>.lua`, wired by `lua/core/dap.lua`. **Add a debugger by
  dropping a file in `dap/`** — never grow `lua/plugins/runtime/dap.lua`.
- **LSP keymaps live in `LspAttach`** (in `lua/core/lsp.lua`), not in
  `core/keymaps.lua` — so they're scoped to clients that actually
  attached. `gr` is owned by `lua/plugins/ui/trouble.lua`.
- **Mason auto-install**: `lua/tools/mason_ensure.lua` is SSOT for **LSP
  + formatters + linters**. DAP installs separately via `mason-registry`
  from `lua/core/dap.lua` (not `mason-nvim-dap`). Skipped under
  `CI=true` / `NO_AUTO_INSTALL=1`.
- **Picker is Snacks.nvim** — no Telescope.
- **Plugin domains are bisection units**: each `lua/plugins/<domain>/`
  is imported separately in `init.lua` so any one can be commented out
  to isolate breakage.

## Forbidding rules / retired designs

These constrain code that *isn't there*; comments have nowhere to live.

- **`<leader>n{d,D,i,u}` are retired.** Don't re-introduce them as
  aliases for `g*`. `<leader>n*` only survives for jumps with **no**
  `g*` counterpart: `<leader>nb` supertypes; IdeaVim-only `<leader>nt`
  GotoTest / `<leader>nf` FindInPath; `<leader>ns` structure popup.
- **`<leader>nt` (GotoTest) is IdeaVim-only.** Neotest is a runner, not
  a navigator — don't invent a heuristic. Use `<leader>tt` or language
  tooling (`:GoAlt`).
- **`<C-x>` is asymmetric on purpose.** Both sides remap Vim's default
  decrement to `<C-S-A>`. Past that, nvim repurposes `<C-x>` as an
  Emacs-style chord prefix (`lua/core/keymaps.lua`); JetBrains routes
  `<C-x>` through its own keymap so chords work outside the editor
  component (tool windows, popups). Don't mirror new `<C-x>*` bindings
  into `.ideavimrc`.
- **DAP keymaps split into static `<leader>d*` and session-only
  `<localleader>*`** (= `,`). Static binds at startup; session binds
  attach on `event_initialized`, detach on `event_terminated`. The
  `actions` local in `lua/plugins/runtime/dap.lua` is SSOT — don't
  duplicate-bind those actions under `<leader>d*`. F-keys intentionally
  unused (leader/localleader stays in Vim grammar, works across keyboard
  layouts).

## Conventions

- Non-plugin config in `lua/core/` only.
- Prefer `opts` over `config` functions.
- Lazy-load with `event` / `ft` / `cmd` / `keys`.
- Always set `desc` on keymaps — which-key relies on it.
- **Before merging any keymap/plugin change, re-check the parity map.**
