# go-context.nvim

Workspace-aware Go build contexts for Neovim.

`go-context.nvim` keeps per-workspace Go build tags outside of the repository and propagates the active context to `gopls`.

It is intentionally small: it manages build context state and exposes it to other tooling instead of trying to be a full Go IDE layer.

> Early development: the current API is small, but not yet guaranteed to be stable.

## Features

- per-workspace Go build tags
- persistent state under Neovim's state directory
- `gopls` integration on startup
- live `workspace/didChangeConfiguration` updates
- isolation between multiple Go workspaces
- public Lua API for other tooling
- no runtime dependencies

## Requirements

- Neovim 0.10+
- `gopls` for LSP integration

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "nashabanov/go-context.nvim",
  lazy = false,
  opts = {},
}
