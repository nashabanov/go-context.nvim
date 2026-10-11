#!/usr/bin/env sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
STATE="$(mktemp -d)"

cleanup() {
    rm -rf "$STATE"
}

trap cleanup EXIT INT TERM

export XDG_STATE_HOME="$STATE"
export NVIM_LOG_FILE="$STATE/nvim.log"

for test in context workspace store gopls integration detect suggest ui; do
    printf 'Running %s...\n' "$test"

    mkdir -p "$STATE/$test"
    export XDG_STATE_HOME="$STATE/$test"

    nvim \
        --headless \
        -u NONE \
        -i NONE \
        -l "$ROOT/tests/$test.lua"
done
