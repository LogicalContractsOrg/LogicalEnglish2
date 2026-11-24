#!/bin/sh
# The oracle: Axiom's engine, axiom-rules-engine (MIT), built from source at
# the commit corpus.pl pins, into .cache/engine-src/target/release/.
#
# The released binaries (v0.2.2, 20 August 2026) refuse fields the corpus
# has used since September, so the engine is built from `main` of the
# corpus's day. It needs Rust (rustup, ~/.cargo) and a C linker; on a machine
# without gcc, Zig serves (pip download ziglang, then a `cc` script running
# `zig cc`, as ~/.local/bin/cc on the build machine of 5 October 2026).
set -e
cd "$(dirname "$0")"
COMMIT=$(sed -n "s/^engine_commit('\([0-9a-f]*\)').*/\1/p" corpus.pl)
mkdir -p .cache
if [ ! -d .cache/engine-src/.git ]; then
    git -c safe.directory=* init -q .cache/engine-src
    git -c safe.directory=* -C .cache/engine-src remote add origin https://github.com/TheAxiomFoundation/axiom-rules-engine.git
fi
if [ "$(git -c safe.directory=* -C .cache/engine-src rev-parse HEAD 2>/dev/null)" != "$COMMIT" ]; then
    git -c safe.directory=* -C .cache/engine-src fetch -q --depth 1 origin "$COMMIT"
    git -c safe.directory=* -C .cache/engine-src -c advice.detachedHead=false checkout -q FETCH_HEAD
fi
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
if ! command -v cc >/dev/null 2>&1 && [ -x "$HOME/.local/bin/cc" ]; then
    export PATH="$HOME/.local/bin:$PATH" CC="$HOME/.local/bin/cc" CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="$HOME/.local/bin/cc"
fi
(cd .cache/engine-src && cargo build --release --bin axiom-rules-engine)
.cache/engine-src/target/release/axiom-rules-engine capabilities
