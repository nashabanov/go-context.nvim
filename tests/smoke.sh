#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
STATE="$(mktemp -d)"
trap 'rm -rf "$STATE"' EXIT INT TERM
export XDG_STATE_HOME="$STATE"
export NVIM_LOG_FILE="$STATE/nvim.log"
export GOCACHE="$STATE/go-cache"
export GOMODCACHE="$STATE/go-mod-cache"
export GOPROXY=off
export GOTOOLCHAIN=local
if ! nvim --headless -u NONE -i NONE -l "$ROOT/tests/gopls-smoke.lua"; then
    if [ -f "$STATE/nvim/lsp.log" ]; then tail -n 80 "$STATE/nvim/lsp.log"; fi
    exit 1
fi
