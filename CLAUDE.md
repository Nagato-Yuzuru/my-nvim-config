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
| Refactor `<leader>r*`                                       | LSP keymaps in `init.lua` (`LspAttach`) + language plugins         |
| Navigation `<leader>n*`                                     | LSP keymaps in `init.lua` (`LspAttach`)                            |
| Views `<leader>v*`                                          | UI plugins in `lua/plugins/ui/` (neo-tree, trouble, toggleterm, …) |
| Reformat `<leader>f*`                                       | `lua/plugins/format/conform.lua`                                   |
| Mark / bookmark `<leader>m*`, `<leader>M`                   | `lua/plugins/edit/marks.lua`                                       |

### The `<C-x>` handling — an intentional asymmetry

Both sides agree on **one** thing: Vim's default `<C-x>` (decrement number) is unbound and remapped to `<C-S-A>`. See `lua/core/keymaps.lua` L6–8 and `.ideavimrc` L32–33.

Beyond that, the two sides diverge **on purpose**:

- **Neovim side**: `<C-x>` is repurposed as an Emacs-style chord prefix. Bindings like `<C-x>t` (new buffer), `<C-x>2`/`<C-x>3` (splits), `<C-x><Tab>` (next tab) live in `lua/core/keymaps.lua`.
- **IdeaVim side**: `<C-x>` is **routed to the IDE itself**, not consumed by IdeaVim. The reason: many of the window/workspace actions that fit under this prefix need to work even when the editor component does not have focus (tool windows, popups, etc.), and IdeaVim — which only intercepts keys inside the editor — cannot cover those cases. So `<C-x>` in JetBrains IDEs is reserved for IDE-level chord shortcuts configured through the IDE's own keymap, not through `.ideavimrc`.

When adding a new `<C-x>*` binding on the Neovim side, do **not** try to mirror it in `.ideavimrc`. Instead, leave the IDE-side binding to the JetBrains keymap and, if the parity matters, document the IDE shortcut in a comment.

## Architecture

```
init.lua              -- Entry: leader keys, clipboard, lazy.nvim bootstrap,
                         vim.lsp.enable(...), LspAttach keymaps, inlay hints
.ideavimrc            -- Hard-linked to ~/.ideavimrc; keep in sync with nvim side
lsp/                  -- Neovim-native per-server LSP config, auto-loaded by
                         vim.lsp.enable() (gopls.lua, pyright.lua, lua_ls.lua, …)
lua/
  core/
    options.lua       -- Vim options (tabs = 4 spaces, UI, diff options)
    keymaps.lua       -- Global keymaps: clipboard, window nav, <C-x> prefix, visual J/K
  plugins/            -- Plugin specs organized by domain (each file returns a lazy.nvim spec)
    lsp/core.lua      -- Mason setup + :SchemaSelect command (NOT the LSP server configs)
    completion/        -- blink.cmp + LuaSnip + blink.compat (zsh completion)
    format/conform.lua -- conform.nvim with format-on-save
    lint/nvim-lint.lua -- nvim-lint
    edit/              -- align, autopairs, autotag, comment, enhance, motion (flash),
                         multi-cursor, rainbow, surround
    ui/                -- tokyonight, bufferline, neo-tree, snacks, toggleterm, trouble,
                         noice, which-key, indent-blankline, fold, todo-comments, …
    git/gitsigns.lua   -- Git integration
    lang/              -- Language-specific plugins (markdown, obsidian, leetcode, d2)
    schemas/           -- Custom JSON/YAML/TOML schema catalog (cloud-native)
    treesitter.lua     -- Treesitter config
  tools/
    mason_ensure.lua   -- Mason auto-install: install primitives + LSP/formatter/linter
                         inventory + VeryLazy and FileType wiring. Single source of truth.
```

### Active lazy.nvim layers

`init.lua` imports **9** layers: `lsp`, `edit`, `format`, `lint`, `completion`, `ui`, `git`, `lang`, `treesitter`. There are no disabled/commented-out layers.

### Key Design Patterns

- **Neovim 0.11+ native LSP**: Server configs live in **top-level `lsp/<server>.lua`** files and are activated via `vim.lsp.enable({...})` in `init.lua`. This repo does **not** use `lspconfig[server].setup()`. Global capabilities (including blink.cmp's) are injected once at `VeryLazy` via `vim.lsp.config("*", { capabilities = ... })`.
- **LSP keymaps via `LspAttach`**: All LSP-related keymaps (`gd`, `gi`, `gr`, `<leader>rn`, `<leader>ca`, `<leader>n*`, etc.) are set in the `LspAttach` autocmd in `init.lua`, not in `core/keymaps.lua`, so they're scoped to buffers with an attached LSP client. Inlay hints are also enabled there.
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
