#!/bin/bash
# vendor_lpsplus.sh — copy what this server uses of the private lpsPlus
# repository into vendor/lpsplus/, for the Docker image.
#
#   ./vendor_lpsplus.sh [/path/to/lpsPlus]      (default: $LPS_PLUS_DIR, then ../lpsPlus)
#
# What it copies: accounts/ (lc_accounts.pl, licenses.csv, passwords.csv —
# signing in and who holds which licence), contract_assistant/ (the LE
# Contract Assistant: its module, prompts, web page and tests, with
# le2_locator.pl, through which it finds this LE2), and
# examples/private/ (the unlisted examples, which open only by their exact
# name, ?example=private/<folder>/<name>: le_kbs:le_private_examples_dir/2
# finds them here; without them that address answers "File not found"). Only
# the files git knows about or would add.
#
# The translators of other systems are no longer copied from there: they are
# this repository's own (migration/), and the Dockerfile copies them. The few
# downloaded files that the Rune door reads are copied by vendor_caches.sh.
#
# vendor/lpsplus/ is gitignored: it is a copy of a PRIVATE repository, with
# the licences and passwords tables in it. It must never be committed here,
# and the WebAssembly build never packs it (wasm/pack.pl).
set -e

cd "$(dirname "$0")"
PLUS="${1:-${LPS_PLUS_DIR:-../lpsPlus}}"
OUT="vendor/lpsplus"

if [ ! -f "$PLUS/accounts/lc_accounts.pl" ]; then
    echo "no lpsPlus at $PLUS (looking for accounts/lc_accounts.pl)." >&2
    echo "usage: ./vendor_lpsplus.sh /path/to/lpsPlus" >&2
    exit 1
fi

echo "vendoring lpsPlus (accounts, contract assistant, private examples) from $PLUS"
rm -rf "$OUT"
mkdir -p "$OUT"
n=0
while IFS= read -r f; do
    [ -f "$PLUS/$f" ] || continue
    mkdir -p "$OUT/$(dirname "$f")"
    cp "$PLUS/$f" "$OUT/$f"
    n=$((n+1))
done < <(git -c safe.directory='*' -C "$PLUS" ls-files --cached --others --exclude-standard -- accounts contract_assistant examples/private le2_locator.pl)
{
    echo "lpsPlus, vendored for the LE2 image by vendor_lpsplus.sh."
    echo "Source: $PLUS"
    echo "Revision: $(git -c safe.directory='*' -C "$PLUS" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo "Vendored: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$OUT/VENDORED.txt"
echo "  $n files, $(du -sh "$OUT" | cut -f1)"
