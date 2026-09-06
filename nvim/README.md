# nvim

Personal Neovim config based on [NvChad](https://github.com/NvChad/NvChad) `v2.5` (lazy.nvim, theme `catppuccin`).

## Requirements

- Neovim 0.11+
- `git`, a C compiler (`cc`/`clang`/`gcc`), `tree-sitter` CLI (parsers are compiled from source)
  ```sh
  brew install tree-sitter-cli
  ```
- `node` / `python3` for some LSP servers and formatters
- A Nerd Font for icons

## Install

```sh
git clone <this-repo> ~/.config/nvim
nvim  # lazy.nvim bootstraps itself, then :Lazy sync
```

Useful follow-ups inside Neovim:

```vim
:Mason          " install LSP servers / formatters
:TSUpdate       " (re)build tree-sitter parsers
```

## Layout

```
init.lua                 lazy.nvim bootstrap + NvChad import
lua/
  chadrc.lua             theme / UI (catppuccin)
  options.lua            vim options + custom filetype mappings
  autocmds.lua           autocmds
  mappings.lua           keymaps
  plugins/init.lua       plugin overrides (lspconfig, conform, treesitter)
  configs/
    lazy.lua             lazy.nvim defaults
    lspconfig.lua        LSP server configs
    conform.lua          formatter configs
```

## Language support

| Language / file      | Tree-sitter        | LSP       | Formatter              |
| -------------------- | ------------------ | --------- | ---------------------- |
| Lua                  | ✓                  | lua_ls *  | stylua                 |
| HTML / CSS           | ✓                  | html/cssls| (prettier, commented)  |
| YAML (OpenShift/K8s) | ✓                  | yamlls    | prettier → yamlfmt     |
| JSON / TOML          | ✓                  | —         | prettier / taplo       |
| Python               | ✓                  | pyright   | ruff_format → black    |
| Bash / shell         | ✓                  | bashls    | shfmt                  |
| dotenv (`.env*`)     | ✓                  | —         | —                      |
| Dockerfile / INI     | ✓                  | —         | —                      |

`*` lua_ls comes from NvChad defaults.

LSP servers are enabled in `lua/configs/lspconfig.lua`:

```lua
{ "html", "cssls", "yamlls", "pyright", "bashls" }
```

Install them (plus formatters) via `:Mason`: `yaml-language-server`,
`pyright`, `bash-language-server`, `prettier`, `yamlfmt`, `taplo`,
`ruff`/`black`, `shfmt`.

## Custom filetypes (`lua/options.lua`)

- `*.build` → `bash` (LSP, `shfmt`, tree-sitter bash apply)
- `.env`, `*.env`, `.env.*` → `dotenv`

bashls background scanning also covers them:

```
*@(.sh|.inc|.bash|.command|.build|.env|.env.*)
```

## YAML notes (`lua/configs/lspconfig.lua`)

- OpenShift / Kubernetes manifests get schema validation
  (`deployment*`, `service*`, `route*`, `dc/bc/is*`, `templates/`,
  `openshift/`, `k8s/`, `*.k8s.yaml`).
- Custom tags (`!Ref`, `!Sub`, `!GetAtt`, …) are tolerated for
  CloudFormation / Tekton / OpenShift templates.
- `yaml.format` is off in yamlls — formatting goes through conform.

## Gotchas

- `nvim-treesitter` is pinned to `branch = "master"` with `build = ":TSUpdate"`.
  NvChad v2.5 uses the old `ensure_installed` API; the `main` branch rewrite
  is incompatible. If parsers fail with `ENOENT ... 'tree-sitter ...'`,
  install the CLI (`brew install tree-sitter-cli`) and rerun `:TSUpdate`.
