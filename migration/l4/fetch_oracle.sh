#!/bin/sh
# L4's own evaluator, compiled to WebAssembly by its authors
# (github.com/smucclaw/l4-ide releases, Apache-2.0), into oracle/ (gitignored).
# Pinned: the runs in runs/ were made with this build; moving it is a
# deliberate step, followed by `l4_oracle.mjs cache --force`.
set -e
BUILD=${L4_ORACLE_BUILD:-vscode-wasm-build-117}
DIR=$(dirname "$0")/oracle
mkdir -p "$DIR"
for f in jl4-core.mjs jl4-core.wasm; do
    [ -s "$DIR/$f" ] || curl -sfL -o "$DIR/$f" "https://github.com/smucclaw/l4-ide/releases/download/$BUILD/$f"
done
echo "$BUILD" > "$DIR/BUILD"
echo "L4 evaluator ($BUILD) in $DIR"
