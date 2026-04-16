# Neovim Quick Reference

Plugin manager: `lazy.nvim`. Leader key: `<Space>`. Hint system: `which-key` (press `<Space>` and pause).

---

## 1. Navigation

### Files & search (Telescope)
| Key | Action |
|-----|--------|
| `<leader>sf` | Find files by name |
| `<leader>sg` | Grep across project |
| `<leader><space>` | Switch open buffers |
| `<leader>/` | Fuzzy search current file |
| `<leader>sw` | Search word under cursor |
| `<leader>go` | Open all git-modified files into buffers |

### File tree (Neo-tree)
| Key | Action |
|-----|--------|
| `<leader>n` | Toggle file tree |
| `q` | Close tree (from inside it) |

### Buffers
| Key | Action |
|-----|--------|
| `L` | Next buffer |
| `H` | Previous buffer |
| `<leader>bd` | Close buffer (preserves layout) |

### Dashboard
Open with `nvim` (no args). Type the number next to a recent file to open it.

### Auto-save
Files save automatically on `InsertLeave`, `BufLeave`, and `FocusLost`.

---

## 2. Editing

### Commenting (native, Neovim 0.10+)
| Key | Action |
|-----|--------|
| `gcc` | Toggle comment on current line |
| `gc<motion>` | Toggle comment over motion (e.g. `gc4j`) |
| `gc` (visual) | Toggle comment on selection |

### Folding (Treesitter)
| Key | Action |
|-----|--------|
| `zc` / `zo` | Close / open fold |
| `za` | Toggle fold |
| `zM` / `zR` | Close all / open all folds |

---

## 3. Splits & pane navigation

New splits open right (`:vsplit`) and below (`:split`).

| Key | Action |
|-----|--------|
| `Ctrl-h/j/k/l` | Move between Neovim splits |
| `Alt-h/j/k/l` | Move between tmux panes (no prefix) |
| `Ctrl-a h/j/k/l` | Move between tmux panes (with prefix) |

---

## 4. LSP

Activated per-buffer when a language server attaches.

| Key | Action |
|-----|--------|
| `gd` | Go to definition (`Ctrl-t` to jump back) |
| `gr` | Go to references (Telescope) |
| `gI` | Go to implementation |
| `K` | Hover documentation |
| `<leader>rn` | Rename symbol across project |
| `<leader>ca` | Code action |
| `<leader>D` | Type definition |
| `<leader>ds` | Document symbols |
| `<leader>ws` | Workspace symbols |
| `<leader>th` | Toggle inlay hints |
| `[d` / `]d` | Previous / next diagnostic |
| `<leader>e` | Floating diagnostic detail |

Mason (`:Mason`) auto-installs LSPs and tools on first launch. Press `g?` inside Mason for help.

---

## 5. Formatting & linting

Formatting runs on save via `conform.nvim`. Manual trigger: `<leader>f`.

| Language | Formatter | Linter |
|----------|-----------|--------|
| Python | `ruff_organize_imports`, `ruff_format` | `ruff` |
| Go | `gofmt`, `goimports` | `golangci-lint` |
| JS/TS | `prettierd` (fallback: `prettier`) | `eslint` |
| Lua | `stylua` | — |
| Shell | `shfmt` | `shellcheck` |
| Markdown | — | `markdownlint` |
| Dockerfile | — | `hadolint` |
| JSON | — | `jsonlint` |

---

## 6. Debugging (DAP)

Env files loaded automatically at session start: `.env`, `.env.local`, `.env.test`, `envs/local.env`, `envs/pytest.env`. `DB_HOSTNAME` and `REDIS_HOST` are forced to `localhost`.

| Key | Action |
|-----|--------|
| `<leader>dt` | Debug test under cursor |
| `<leader>dc` | Debug class (Python) |
| `<F5>` | Start / continue |
| `<F1>` / `<F2>` / `<F3>` | Step into / over / out |
| `<leader>b` | Toggle breakpoint |
| `<leader>B` | Conditional breakpoint |
| `<F7>` | Toggle DAP UI |

To add a new debugger: add the adapter plugin to `lua/plugins/debugging.lua` dependencies, then add an `elseif filetype == "..."` branch in `run_debug_test()`.

---

## 7. Testing (Neotest)

Shares the same env-loading logic as the debugger.

| Key | Action |
|-----|--------|
| `<leader>tr` | Run nearest test |
| `<leader>tf` | Run all tests in file |
| `<leader>ts` | Toggle summary panel |
| `<leader>tp` | Toggle output panel |
| `<leader>to` | Output for test under cursor |
| `<leader>ta` | Attach to running test |
| `o` | Open output (inside summary panel) |

To add a new adapter: add it to `lua/plugins/testing.lua` dependencies and register it in `neotest.setup({ adapters = { ... } })`.

---

## 8. Terminal

| Key | Action |
|-----|--------|
| `<leader>;` | Toggle floating terminal |
| `Esc Esc` | Close terminal |

---

## 9. Git

| Key | Action |
|-----|--------|
| `<leader>gg` | Open LazyGit (full-screen float) |
| `<leader>gb` | Open current file on GitHub |

**Inside LazyGit:** `Space` stage/unstage, `c` commit, `P` push, `p` pull, `q` quit.

**Merge conflicts (`git-conflict.nvim`):**

| Key | Action |
|-----|--------|
| `]x` / `[x` | Next / previous conflict |
| `co` | Choose ours |
| `ct` | Choose theirs |
| `cb` | Choose both |
| `c0` | Choose none (manual edit) |

---

## 10. Markdown

`render-markdown.nvim` hides raw syntax and renders headings, checkboxes, and bullets inline.

| Key | Action |
|-----|--------|
| `<leader>tm` | Toggle markdown rendering |

---

## 11. Copilot

| Key | Action |
|-----|--------|
| `<Tab>` | Accept suggestion |
| `<Alt-]>` / `<Alt-[>` | Next / previous suggestion |
| `<Ctrl-]>` | Dismiss suggestion |

First run: `:Copilot auth`.
