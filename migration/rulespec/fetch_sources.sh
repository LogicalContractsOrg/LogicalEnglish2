#!/bin/sh
# Axiom RuleSpec: rulespec-us (Axiom Foundation, CC-BY-4.0) at the commit
# corpus.pl pins, into .cache/rulespec-us (gitignored), then the normalised
# copy the engine loads (prepare_root.py -> .cache/root/rulespec-us).
set -e
cd "$(dirname "$0")"
COMMIT=$(sed -n "s/^corpus_commit('\([0-9a-f]*\)').*/\1/p" corpus.pl)
mkdir -p .cache
if [ ! -d .cache/rulespec-us/.git ]; then
    git -c safe.directory=* init -q .cache/rulespec-us
    git -c safe.directory=* -C .cache/rulespec-us remote add origin https://github.com/TheAxiomFoundation/rulespec-us.git
fi
if [ "$(git -c safe.directory=* -C .cache/rulespec-us rev-parse HEAD 2>/dev/null)" != "$COMMIT" ]; then
    git -c safe.directory=* -C .cache/rulespec-us fetch -q --depth 1 origin "$COMMIT"
    git -c safe.directory=* -C .cache/rulespec-us -c advice.detachedHead=false checkout -q FETCH_HEAD
fi
echo "rulespec-us at $(git -c safe.directory=* -C .cache/rulespec-us rev-parse --short HEAD) in .cache/rulespec-us"
python3 prepare_root.py
