#!/bin/sh
# The RUML specification, its schemas, examples and conformance tests
# (Law-as-Code-Institute/ruml: specification text CC BY-SA 4.0, everything else
# Apache-2.0, copyright Rulemapping Group GmbH), at release 1.0.0, into
# .cache/ruml (gitignored). The two parser libraries are fetched beside it for
# reading only: neither has an evaluator.
# Run once before build.pl, gate.pl or the tests.
set -e
cd "$(dirname "$0")"
mkdir -p .cache
fetch() {   # name commit [owner]
    if [ ! -d ".cache/$1/.git" ]; then
        git -c safe.directory=* init -q ".cache/$1"
        git -c safe.directory=* -C ".cache/$1" remote add origin "https://github.com/${3:-Law-as-Code-Institute}/$1.git"
    fi
    if [ "$(git -c safe.directory=* -C ".cache/$1" rev-parse HEAD 2>/dev/null)" != "$2" ]; then
        git -c safe.directory=* -C ".cache/$1" fetch -q --depth 1 origin "$2"
        git -c safe.directory=* -C ".cache/$1" checkout -q FETCH_HEAD
    fi
    echo "$1 at $(git -c safe.directory=* -C ".cache/$1" rev-parse --short HEAD) in .cache/$1"
}
fetch ruml        d2ac818f6ed87c2bcf5b69430adf2efa8ba3c6a4
fetch ruml-js     cb7d754b42ff53940e154ae924b7f72f7fa8b218
fetch ruml-python 1a421333ba0a2b4d134054417dc418c1142916ec
# The second opinion of the oracle (MIT licence, not the publisher's; the design notes ruml.md §8).
fetch ruml-tooling 6b061f5bd2d2f065f810d462dc84fa99397ac77f TechPrototyper
[ -d node_modules/jsonata ] || npm install --no-audit --no-fund --silent
