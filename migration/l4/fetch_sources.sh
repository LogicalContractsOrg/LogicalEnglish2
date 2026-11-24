#!/bin/sh
# The L4 corpus: the smucclaw/l4-ide repository (Apache-2.0, Singapore
# Management University) at the commit corpus.pl pins, into .cache/l4-ide
# (gitignored). Only the files corpus.pl lists are read.
set -e
cd "$(dirname "$0")"
COMMIT=$(sed -n "s/^corpus_commit('\([0-9a-f]*\)').*/\1/p" corpus.pl)
mkdir -p .cache
if [ ! -d .cache/l4-ide/.git ]; then
    git -c safe.directory=* init -q .cache/l4-ide
    git -c safe.directory=* -C .cache/l4-ide remote add origin https://github.com/smucclaw/l4-ide.git
fi
if [ "$(git -c safe.directory=* -C .cache/l4-ide rev-parse HEAD 2>/dev/null)" != "$COMMIT" ]; then
    git -c safe.directory=* -C .cache/l4-ide fetch -q --depth 1 origin "$COMMIT"
    git -c safe.directory=* -C .cache/l4-ide checkout -q FETCH_HEAD
fi
echo "l4-ide at $(git -c safe.directory=* -C .cache/l4-ide rev-parse --short HEAD) in .cache/l4-ide"
