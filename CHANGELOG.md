# Changelog

## v1.0.0

### Fixed

- Apply saved tags during gopls initialization even when `settings` is absent.
- Support runtime configuration notifications on Neovim 0.10 and newer, and report notification failures.
- Normalize workspace roots to absolute paths and reject empty roots.
- Distinguish missing state from filesystem errors and validate stored context structure.
- Delete persisted state before clearing client tags, so deletion failures leave client settings unchanged.
- Reject malformed tag lists instead of silently ignoring their contents.
- Clean up temporary state files after write failures and scratch buffers after window creation failures.

### Maintenance

- Expand tests for workspace isolation, persistence failures, public API behavior, LSP updates, and UI lifecycle.
- Add a separate smoke test using a real gopls server.
- Add StyLua configuration and CI formatting checks; run unit tests on Neovim 0.10.4.
- Document API and event contracts, storage semantics, error handling, and supported limitations.
- Add Makefile targets for formatting, unit tests, and the optional integration smoke test.

The public API and version-1 storage format are preserved. No new user-facing features or dependencies are introduced.

## v0.1.0

Initial release.

### Added

- Per-workspace Go build tag contexts persisted outside the repository in version-1 JSON records.
- `GoContext`, `GoContext!`, and `GoContextClear` commands with a floating input for editing tags.
- Lua API for resolving workspace roots and reading, setting, and clearing contexts.
- gopls integration through `before_init` and runtime configuration updates.
- Suggestions for custom tags in the current buffer's `//go:build` directives, with a floating selection UI and per-workspace suppression of declined tags for the session.
- `User GoContextChanged` event for external integrations.
- Headless Neovim tests, a basic GitHub Actions workflow, README, Neovim help, and MIT license.
