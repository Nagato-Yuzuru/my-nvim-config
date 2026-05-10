# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal Neovim configuration using **lazy.nvim** as the plugin manager. All configuration is in Lua, targeting Neovim 0.11+ (uses the native `vim.lsp.enable()` + top-level `lsp/` directory convention).

## Core Principle: Cross-editor Parity

**The single most important constraint of this repo:** the editing experience in Neovim and JetBrains IDEs (via IdeaVim) must stay as consistent as possible. The user works daily in both, and muscle memory must transfer between them.

- **`.ideavimrc` is linked to `~/.ideavimrc`** so that IdeaVim reads this repo's file directly. Editing `.ideavimrc` in this repo immediately affects every JetBrains IDE on the machine.
- When adding or changing a keymap, plugin, or workflow on the Neovim side, **check `.ideavimrc` and mirror the binding** whenever an equivalent IDE Action exists. When no equivalent exists (e.g. Flash Treesitter has no IdeaVim counterpart), leave a comment on the IdeaVim side explaining why it's intentionally unbound.
- Conversely, when touching `.ideavimrc`, check the corresponding Neovim file and keep the two in sync.
- Asymmetries are allowed when Neovim genuinely has more capability than IdeaVim (e.g. multi-list bookmarks, Flash Treesitter). When this happens, the nvim-only extras must be documented as a comment block in the relevant `.ideavimrc` section so both sides share the same source of truth for what's bound where.

### Parity map (which .ideavimrc section corresponds to which nvim file)

| `.ideavimrc` section                                        | Neovim counterpart                                                 |
| ----------------------------------------------------------- | ------------------------------------------------------------------ |
| Leader + clipboard + `J`/`K` visual move + `<C-x>` handling | `lua/core/keymaps.lua`                                             |
| easymotion `<leader><leader>*`                              | `lua/plugins/edit/motion.lua` (flash.nvim)                         |
| multi-cursor `<A-n>`/`<A-p>`/`<A-x>`                        | `lua/plugins/edit/multi.lua`                                       |
| Refactor `<leader>r*`                                       | LSP keymaps in `lua/core/lsp.lua` (`LspAttach`) + language plugins |
| Core navigation `g*` (`gd`/`gD`/`gi`/`gr`)                  | LSP keymaps in `lua/core/lsp.lua` (`LspAttach`) + `lua/plugins/ui/trouble.lua` (`gr`) |
| Preview `gp*` (nvim-only — IDE uses `⌥Space` Quick Def)     | `lua/plugins/lsp/preview.lua` (goto-preview)                       |
| Navigation extras `<leader>n*` (no `g*` equivalent), plus `<leader>n{h,j,k,l}` walker hydra (nvim-only) | LSP keymaps in `lua/core/lsp.lua` (`LspAttach`) + `lua/plugins/ui/aerial.lua` + `lua/plugins/ui/hydra.lua` (treewalker) |
| Search `<leader>s*` (nvim-only — IDE uses Search Everywhere) | `lua/plugins/ui/snacks.lua`                                       |
| Views `<leader>v*`                                          | UI plugins in `lua/plugins/ui/` (neo-tree, trouble, toggleterm, …) |
| Reformat `<leader>f*`                                       | `lua/plugins/format/conform.lua`                                   |
| Mark / bookmark `<leader>m*`, `<leader>M`                   | `lua/plugins/edit/marks.lua`                                       |
| Debug `<leader>D` / `<leader>d*` / `<leader>vd` (static), `<localleader>*` (session-scoped) | `lua/plugins/runtime/dap.lua`                                      |
| Run / Task `<leader>vr`, `<leader>o*` (nvim-only)           | `lua/plugins/runtime/overseer.lua`                                 |
| Test `<leader>t*` (nvim-only)                               | `lua/plugins/runtime/neotest.lua`                                  |

### Navigation `g*` — two intentional decisions

The bindings themselves are in `lua/core/lsp.lua` / `.ideavimrc`. The code
can tell you **what**; these two points are the **why**:

1. **`gD = type_definition`, not `declaration`** (diverges from Kickstart/
   LazyVim). Declaration vs. definition is only distinct in C/C++ (header
   vs. impl) and Objective-C; for our stack (Lua/Py/TS/Go/shell/…) both
   LSP requests return identical results, so `gD = declaration` is a
   wasted keystroke. C/C++ users wanting header ↔ impl should use
   `:ClangdSwitchSourceHeader` — more precise than `gD` anyway.

2. **`<leader>nd`/`nD`/`ni`/`nu` are retired by design.** They used to
   mirror `g*`; removed to stay aligned with community muscle memory.
   Do **not** re-introduce them as aliases. `<leader>n*` only survives
   for jumps with **no** `g*` counterpart: `<leader>nb` supertypes (both
   sides), IdeaVim-only `<leader>nt` GotoTest / `<leader>nf` FindInPath.
   `<leader>ns` is the structure popup (transient picker, not a jump);
   the persistent structure sidebar lives at `<leader>vs` in the Views
   namespace, since "open a tool window" is the `<leader>v*` contract.

### The `<C-x>` handling — an intentional asymmetry

Both sides agree on **one** thing: Vim's default `<C-x>` (decrement number) is unbound and remapped to `<C-S-A>`. See `lua/core/keymaps.lua` L6–8 and `.ideavimrc` L32–33.

Beyond that, the two sides diverge **on purpose**:

- **Neovim side**: `<C-x>` is repurposed as an Emacs-style chord prefix. Bindings like `<C-x>t` (new buffer), `<C-x>2`/`<C-x>3` (splits), `<C-x><Tab>` (next tab) live in `lua/core/keymaps.lua`.
- **IdeaVim side**: `<C-x>` is **routed to the IDE itself**, not consumed by IdeaVim. The reason: many of the window/workspace actions that fit under this prefix need to work even when the editor component does not have focus (tool windows, popups, etc.), and IdeaVim — which only intercepts keys inside the editor — cannot cover those cases. So `<C-x>` in JetBrains IDEs is reserved for IDE-level chord shortcuts configured through the IDE's own keymap, not through `.ideavimrc`.

When adding a new `<C-x>*` binding on the Neovim side, do **not** try to mirror it in `.ideavimrc`. Instead, leave the IDE-side binding to the JetBrains keymap and, if the parity matters, document the IDE shortcut in a comment.

### Runtime suite (DAP / Overseer / Neotest) — partial parity, by design

The "runtime" layer (debug / run / test) lives in `lua/plugins/runtime/`. Two
intentional design points:

1. **Two-layer DAP keymap split: `<leader>d*` (static) vs `<localleader>*`
   (session-scoped).** The `<leader>d*` namespace is bound at startup and
   covers editor-state actions that make sense outside a debug session —
   start/continue (`<leader>D`), toggle breakpoint (`<leader>db`), set
   logpoint (`<leader>dt`), pick attach config (`<leader>dA`), focus dap-ui
   panels (`<leader>dv*`), etc. Step / inspect / frame-walk actions only make
   sense **inside a session** and are bound under `<localleader>` (= `,`)
   exclusively, attached on `event_initialized` and detached on
   `event_terminated`. The keys use CLI-debugger mnemonics, not F-keys:
   `,n` (next / step over), `,s` (step into), `,f` (finish / step out) match
   `n`/`s`/`f` from pdb, dlv, and gdb verbatim; `,c` continue, `,p` pause,
   `,u` run-to-cursor (until), `,r` toggle REPL, `,e` inspect expression
   (also visual), `,h` hover variable, `,w` add watch from source (also
   visual), `,j`/`,k` frame down/up, `,R` restart, `,q` terminate. F-keys
   (`<F7>`/`<F8>` JetBrains-style) are intentionally **not** bound — leader
   / localleader stays in the Vim grammar and reaches across keyboard
   layouts. JetBrains keeps its native F-key keymap; that's an asymmetry we
   accept. Action table (the single source of truth) is in the `actions`
   local in `lua/plugins/runtime/dap.lua` — do not duplicate-bind those
   actions under `<leader>d*`.

2. **`<leader>nt` (GotoTest) is IdeaVim-only.** Neotest has no native
   "navigate to test file" command — it's a runner, not a navigator. The
   IdeaVim-side binding survives because GotoTest is a JetBrains IDE Action;
   on Neovim use `<leader>tt` (run nearest test) or language-specific tools
   (`:GoAlt`, etc.). Do not invent a fragile heuristic to mimic GotoTest.

3. **DAP adapters install via mason-registry directly**, called from
   `lua/core/dap.lua` (which scans `dap/<adapter>.lua` files for `mason = ...`
   fields). We do **not** use `mason-nvim-dap` — its `setup_handlers` model
   duplicates what our per-adapter files already do, and its adapter-name
   namespace (`python`, `js`) doesn't match the mason package namespace
   (`debugpy`, `js-debug-adapter`), creating two sources of truth. Per-adapter
   files keep `mason = "<raw-mason-pkg>"`. `tools/mason_ensure.lua` remains
   the single source of truth for **LSP + formatters + linters**; DAP is
   parallel and self-contained under `dap/`.

4. **`dap/<adapter>.lua` is keyed by adapter, not by language** (mirroring
   `lsp/<server>.lua` being keyed by server). `dap/codelldb.lua` therefore
   bundles `c` / `cpp` / `rust` because codelldb is a single binary with
   identical adapter spec for all three. **Trigger to split**: when a language
   needs distinct configurations (e.g. Rust wanting `cargo run` integration
   or auto-pointing `program` at `target/debug/<crate>`), pull it into its
   own file (e.g. `dap/rust.lua`) — both files keep `type = "codelldb"`, the
   orchestrator overwrites the (identical) adapter spec from the second-loaded
   file harmlessly and registers each file's configurations under its own
   filetypes.

## Architecture

The layout is self-describing — see `ls` / the tree in your editor. The
non-obvious things that `ls` can't tell you are below.

### Key Design Patterns

- **Neovim 0.11+ native LSP**: Server configs live in **top-level `lsp/<server>.lua`** files and are activated via `vim.lsp.enable({...})` in `lua/core/lsp.lua` (invoked from `init.lua`). This repo does **not** use `lspconfig[server].setup()`. Global capabilities (including blink.cmp's) are injected once at `VeryLazy` via `vim.lsp.config("*", { capabilities = ... })`.
- **DAP per-adapter split (mirrors LSP layout)**: Each debug adapter lives in **top-level `dap/<adapter>.lua`** as a self-contained spec table (`type` / `mason` / `filetypes` / `adapter` / `configurations`). The orchestrator `lua/core/dap.lua` scans the directory at runtime and wires each spec into `dap.adapters` / `dap.configurations`, returning the list of mason package names which `lua/plugins/runtime/dap.lua` hands to `mason-registry` for install. **To add a new debugger, drop a single file into `dap/`** — never grow `runtime/dap.lua`. The plugin spec stays small (plugin deps + keymaps + UI/sign + one `core.dap.setup()` call).
- **LSP keymaps via `LspAttach`**: All LSP-related keymaps (`gd`/`gD`/`gi`, `<leader>rn`, `<leader>ca`, `<leader>nb`, `<C-k>` signature in insert, etc.) are set in the `LspAttach` autocmd in `lua/core/lsp.lua`, not in `core/keymaps.lua`, so they're scoped to buffers with an attached LSP client. `gr` is handled by `lua/plugins/ui/trouble.lua` (Trouble UI instead of raw quickfix). Inlay hints are also enabled in `LspAttach`. See the `g*` navigation table above for the full scheme.
- **Modular lazy.nvim imports**: `init.lua` uses `spec = { import = "plugins.<domain>" }`. Each subdirectory is a self-contained import layer that can be commented out independently for bisection.
- **Mason auto-install**: `tools/mason_ensure.lua` is the single source of truth — it holds the install primitives (`has_exec`, `ensure_mason_pkg`, `ensure_tools`), the project-specific inventory (`LSP_TOOLS`, `FORMATTERS_BY_FT`, `LINTERS_BY_FT`), and the wiring to `VeryLazy` (LSP servers) and `FileType` autocmds (formatters/linters). Install is skipped when `CI=true` or `NO_AUTO_INSTALL=1`.
- **Schema selection**: `:SchemaSelect` (bound to `<leader>cs`) applies JSON/YAML/TOML schemas from SchemaStore + the custom cloud-native catalog in `plugins/schemas/cloud_native_schema.lua`. Implemented in `plugins/lsp/core.lua`.
- **Snacks.nvim as picker**: `Snacks.picker` is the project's fuzzy finder (`<leader>,` buffers, `<leader>/` grep, etc.). No Telescope.

## Conventions

- All plugin spec files must `return` a table (lazy.nvim spec format).
- Non-plugin configuration goes in `lua/core/` only.
- Prefer `opts` over `config` functions in plugin specs when possible.
- Use `event`, `ft`, `cmd`, or `keys` for lazy-loading.
- Indentation: tabs in Lua files (per existing code style).
- When adding a keymap, always set a `desc` — which-key relies on it.
- **Before merging any keymap/plugin change, re-check the parity map above.**
