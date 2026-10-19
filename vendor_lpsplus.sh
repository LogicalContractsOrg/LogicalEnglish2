#!/bin/bash
# vendor_lpsplus.sh — copy what this server uses of the private lpsPlus
# repository into vendor/lpsplus/, for the Docker image.
#
#   ./vendor_lpsplus.sh [/path/to/lpsPlus]      (default: $LPS_PLUS_DIR, then ../lpsPlus)
#
# What it copies: accounts/ (lc_accounts.pl, licenses.csv, passwords.csv —
# signing in and who holds which licence), migration/ (the translators of
# other systems that File ▸ Open and Export offer) and contract_assistant/
# (the LE Contract Assistant: its module, prompts, web page and tests). Only the files git knows
# about or would add: the gitignored caches of fetched sources and tools
# (gigabytes of them) stay behind, except the few the Rune door reads (below).
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

echo "vendoring lpsPlus (accounts, translators, contract assistant) from $PLUS"
rm -rf "$OUT"
mkdir -p "$OUT"
n=0
while IFS= read -r f; do
    [ -f "$PLUS/$f" ] || continue
    mkdir -p "$OUT/$(dirname "$f")"
    cp "$PLUS/$f" "$OUT/$f"
    n=$((n+1))
done < <(git -c safe.directory='*' -C "$PLUS" ls-files --cached --others --exclude-standard -- accounts migration contract_assistant)
# The Rune door (File ▸ Open of a .rosetta file or a zip of them) translates
# over ISDA's DRR 7.14.0, downloaded by migration/rune/fetch_sources.sh into
# migration/rune/.cache, which git ignores: so copied here by name. Only what
# an import and an export read: DRR's Rune files, the test pack it takes
# scenarios from, the instructions of the CSA chain, and the model as JSON
# (rosetta2json's output, which Export ▸ Rune loads) (about 60 MB). The prebuilt twins
# (examples/migration/rune, 108 MB) are not copied: without them an upload of
# DRR's own files is translated afresh rather than copied (rune_import_run.pl).
RUNE_CACHE="$PLUS/migration/rune/.cache"
if [ -d "$RUNE_CACHE/drr/drr/rosetta" ]; then
    for d in drr/drr/rosetta drr/regulatory-reporting drr/enrich chain json; do
        if [ -d "$RUNE_CACHE/$d" ]; then
            mkdir -p "$OUT/migration/rune/.cache/$(dirname "$d")"
            cp -R "$RUNE_CACHE/$d" "$OUT/migration/rune/.cache/$d"
        fi
    done
    #  and the small library of Rune's operations in LE that every twin
    #  includes (examples/migration/rune/lib: rune.le, rune.pl)
    if [ -d "$PLUS/examples/migration/rune/lib" ]; then
        mkdir -p "$OUT/examples/migration/rune"
        cp -R "$PLUS/examples/migration/rune/lib" "$OUT/examples/migration/rune/lib"
    fi
    echo "  Rune: DRR 7.14.0's Rune files and test pack, $(du -sh "$OUT/migration/rune/.cache" | cut -f1)"
else
    echo "  Rune: no DRR download at $RUNE_CACHE (run migration/rune/fetch_sources.sh): File ▸ Open of .rosetta will not work on this server" >&2
fi
{
    echo "lpsPlus, vendored for the LE2 image by vendor_lpsplus.sh."
    echo "Source: $PLUS"
    echo "Revision: $(git -c safe.directory='*' -C "$PLUS" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo "Vendored: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$OUT/VENDORED.txt"
echo "  $n files, $(du -sh "$OUT" | cut -f1)"
