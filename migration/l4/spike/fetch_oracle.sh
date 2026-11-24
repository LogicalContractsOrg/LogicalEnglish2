#!/bin/sh
# Fetches L4's own evaluator, compiled to WebAssembly by its authors
# (github.com/smucclaw/l4-ide, Apache-2.0), into oracle/ (not committed).
# Pinned to the release the spike used; change BUILD to move.
set -e
BUILD=vscode-wasm-build-117
DIR=$(dirname "$0")/oracle
mkdir -p "$DIR"
for f in jl4-core.mjs jl4-core.wasm; do
    curl -sfL -o "$DIR/$f" "https://github.com/smucclaw/l4-ide/releases/download/$BUILD/$f"
done
echo "L4 evaluator ($BUILD) in $DIR"
