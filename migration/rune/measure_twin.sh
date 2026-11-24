#!/bin/sh
# The measure of a twin (README.md, steps 2 and 7): each scenario file of
# examples/migration/rune/<twin>/ checked by check.pl against DRR's expected
# reports, then summed by summary.py into runs/<twin>.txt.
#
#   measure_twin.sh cftc_part45 [seconds per instruction]
#
# The scenario files are those that include the twin; the twin's own layers
# (<twin>.le, <twin>_drr.le, <twin>_cdm.le), the library and the files of the
# way back are not scenario files.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
LE2=${LE2_DIR:-$HERE/../..}
T=$1; LIMIT=${2:-300}
# the private place of the Rune twins (../le2_paths.pl, private_root/1)
PRIVATE=${LE_PRIVATE_TWINS_DIR:-$HERE/../../../lpsPlus}
D=$PRIVATE/examples/migration/rune/$T
for f in "$D"/*.le; do
  b=$(basename "$f" .le)
  case "$b" in
    "$T"|"$T"_drr|"$T"_cdm|rune|back_*|*_margin_call) continue ;;
  esac
  grep -q "^    $T\.\?$\|^    $T,\|, $T\.\?$" "$f" || continue
  (cd "$LE2" && ./myswipl.sh -q "$HERE/check.pl" -- "$f" "$LIMIT") 2>/dev/null | tail -1
done
python3 "$HERE/summary.py" "$T" > "$HERE/runs/$T.txt"
head -1 "$HERE/runs/$T.txt"
