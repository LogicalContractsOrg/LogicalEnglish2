#!/bin/bash
# vendor_caches.sh — copy the few downloaded files that a translator reads at
# run time into vendor/caches/, for the Docker image.
#
#   ./vendor_caches.sh
#
# The translators of other systems (migration/) keep what they download in
# `.cache/` folders, which git ignores and which the image does not copy:
# they hold gigabytes of other systems' corpora and engines, for the checks.
# One door reads its download when a visitor opens a file:
#
#   Rune (File ▸ Open of a .rosetta file or a zip of them, Export ▸ Rune)
#   translates over ISDA's DRR 7.14.0, downloaded by
#   migration/rune/fetch_sources.sh into migration/rune/.cache. Copied here:
#   DRR's Rune files, the test pack it takes scenarios from, the instructions
#   of the CSA chain, and the model as JSON (rosetta2json's output, which
#   Export ▸ Rune loads) — about 60 MB.
#
# The Dockerfile puts vendor/caches/<door>/ back at migration/<door>/.cache/.
# vendor/caches/ is gitignored: the files are other parties', fetched, and
# not redistributed with this repository.
set -e

cd "$(dirname "$0")"
OUT="vendor/caches"
rm -rf "$OUT"
mkdir -p "$OUT"

RUNE_CACHE="migration/rune/.cache"
if [ -d "$RUNE_CACHE/drr/drr/rosetta" ]; then
    for d in drr/drr/rosetta drr/regulatory-reporting drr/enrich chain json; do
        if [ -d "$RUNE_CACHE/$d" ]; then
            mkdir -p "$OUT/rune/$(dirname "$d")"
            cp -R "$RUNE_CACHE/$d" "$OUT/rune/$d"
        fi
    done
    echo "  Rune: DRR 7.14.0's Rune files and test pack, $(du -sh "$OUT/rune" | cut -f1)"
else
    echo "  Rune: no DRR download at $RUNE_CACHE (run migration/rune/fetch_sources.sh): File ▸ Open of .rosetta will not work on this server" >&2
fi
