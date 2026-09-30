# go-context.nvim

Per-workspace Go build tags for Neovim.

Save build tags between sessions, apply them to `gopls`, and get suggestions for
custom tags found in a Go file's `//go:build` directive. Each workspace has its
own context, stored outside your repository.

## Features

- Manage build tags through commands or a Lua API.
- Persist workspace contexts across Neovim sessions.
- Apply saved tags when `gopls` starts through `before_init`.
- Update running `gopls` clients when the context changes.
- Suggest new tags from the current Go buffer, with user confirmation.
- Integrate with other tools through the `User GoContextChanged` event.

## Requirements

- Neovim 0.10 or later.
- An installed and configured `gopls` for LSP integration.

The plugin does not install or start `gopls`. No additional Lua dependencies are
required.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "nashabanov/go-context.nvim",
  lazy = false,
  config = function()
    require("go-context").setup()
  end,
}
```

With another plugin manager, install `nashabanov/go-context.nvim` and call:

```lua
require("go-context").setup()
```

`setup()` registers the commands and the `BufEnter *.go` handler. There are
currently no configuration options.

## gopls integration

Add `before_init` to your existing `gopls` configuration to apply the saved
context when the server starts:

```lua
before_init = require("go-context").before_init,
```

If you already use a `before_init` callback, combine the calls:

```lua
before_init = function(params, config)
  -- Your existing configuration changes.
  require("go-context").before_init(params, config)
end,
```

When the context changes, the plugin sends `workspace/didChangeConfiguration`
to running `gopls` clients with a matching workspace root. Tags are applied through
`settings.gopls.buildFlags`: existing `-tags` flags are replaced, while other
flags are preserved. Clearing the context removes `-tags`.

## Usage

See `:help go-context` for in-editor help and `:help :GoContext` for commands.

Open a Go file inside a workspace and set the tags you need:

```vim
:GoContext integration,smoke
```

This replaces the current tag list. Tags can be separated by commas or spaces;
duplicates are removed while preserving order.

| Command | Action |
| --- | --- |
| `:GoContext` | Open a compact floating input with the current values |
| `:GoContext integration,smoke` | Replace the workspace tags |
| `:GoContext integration smoke` | Replace tags using a space-separated list |
| `:GoContext!` | Clear the workspace context |
| `:GoContextClear` | Clear the workspace context |

The input opens in a compact floating window with colors from your theme.
Press Enter to save or Esc to cancel. Submitting an empty value in `:GoContext`
saves an empty tag list. The clear
commands also remove the workspace's saved record.

### Suggestions from Go files

On entering a `*.go` buffer, the plugin reads from the beginning of that buffer
to the `package` declaration and extracts custom tags from `//go:build`.

For example, if your context already includes `integration` and a file contains:

```go
//go:build integration && postgres

package storage
```

Only `postgres` is suggested. Accepting it changes the context to
`{ "integration", "postgres" }`. A compact floating window shows the new tags
and two actions: **Add tags** and **Ignore for this session**. Use `j`/`k`, arrow
keys, or Tab to choose, Enter to confirm, and Esc to cancel.

- Accepted tags are appended to the existing tags and saved through the normal context update path.
- Declined tags are not suggested again in that workspace for the rest of the Neovim session.
- Dismissing the prompt counts as declining.
- Declining a tag in one workspace does not affect suggestions in another.

Suggestions exclude GOOS and GOARCH values, `unix`, `cgo`, `gc`, `gccgo`, `ignore`,
release tags matching `go1.<number>`, and directly negated tags such as
`!enterprise`.

Detection extracts identifiers without fully parsing the boolean expression.
For `postgres || sqlite`, both tags are suggested; choosing an appropriate
combination is up to you. Legacy `// +build` directives and filename constraints
such as `_linux.go` are not considered.

## Workspaces and storage

The workspace root comes from the `root_dir` of the `gopls` client attached to
the buffer. If no client root is available, the plugin searches parent directories
for `go.work` or `go.mod`. If attached clients have multiple distinct roots, the
plugin does not choose a workspace automatically.

Roots are normalized, and each workspace context is stored in a JSON file:

```text
stdpath("state")/go_context.nvim/<root hash>.json
```

No files are added to your repository. Declined suggestions are kept only in
memory for the current session.

The plugin detects tags only in the current buffer. It does not scan project
files or remove tags automatically. The context does not modify `go test`,
debugger, or linter commands; use the Lua API and context change event to build
your own integrations.

## Lua API

```lua
local go_context = require("go-context")

-- Use the current buffer's workspace.
local root, err = go_context.root()
local context, err = go_context.get()
local tags = go_context.tags()

-- Replace the context; duplicate tags are removed.
go_context.set({ tags = { "integration", "smoke" } })

-- Delete the saved context and clear tags in gopls.
go_context.clear()
```

Context format:

```lua
{
  tags = { "integration", "smoke" },
}
```

`root`, `get`, `tags`, `set`, and `clear` accept an optional `opts` table.
Pass it as the second argument to `set`, or as the first argument to the other
methods:

```lua
-- Use a specific buffer's workspace.
local context = go_context.get({ bufnr = 12 })

-- An explicit root takes precedence over bufnr.
go_context.set({ tags = { "e2e" } }, { root = "/path/to/workspace" })
local tags = go_context.tags({ root = "/path/to/workspace" })
go_context.clear({ root = "/path/to/workspace" })
```

`get()` returns `nil` when no saved context exists, or `nil, err` on failure.
`root()` returns `nil, err` when the root cannot be resolved. `tags()` returns a
copy of the tag list, or `{}` if the context is unavailable. `set()` and `clear()`
return the resulting context and raise a Lua error on failure.

### Context change event

A successful `set()` or `clear()` triggers `User GoContextChanged`.
`event.data` contains the normalized root and a copy of the new context:

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "GoContextChanged",
  callback = function(event)
    local root = event.data.root
    local tags = event.data.context.tags
    -- Update your integration here.
  end,
})
```

## Development

Run the tests from the repository root:

```sh
./tests/run.sh
```

Tests run in headless Neovim with a temporary state directory. They cover context
handling, persistence, `gopls` integration, tag detection, and suggestions with a
mocked UI.
