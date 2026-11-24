#!/bin/sh
# Blawx (Lexpedite, MIT licence) at its last release, v1.6.22-alpha, into
# .cache/blawx (gitignored): the example projects (blawx/static/blawx/examples)
# are the corpus, and the reasoner's preamble (passthrough.py, ldap.py,
# dates.py, aggregates.py, events.py) is what oracle.py runs them with.
set -e
cd "$(dirname "$0")"
COMMIT=3de892f67854292b304c9a55c5e2cd2058d3d418
mkdir -p .cache
if [ ! -d .cache/blawx/.git ]; then
  git clone -q --filter=blob:none https://github.com/Lexpedite/blawx .cache/blawx
fi
git -C .cache/blawx -c advice.detachedHead=false checkout -q "$COMMIT"
echo "Blawx $COMMIT in $(pwd)/.cache/blawx"
