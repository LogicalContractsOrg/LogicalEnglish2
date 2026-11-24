#!/bin/sh
# Phase 0 of the design notes Excel.md §7.7: every fetched workbook read and
# recalculated by the sheet engine; one JSON per file in runs/survey, and
# the summary table survey.md (survey_report.py).
cd "$(dirname "$0")"
LE2=${LE2_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}
mkdir -p runs/survey
for f in .cache/files/*.xlsx .cache/files/*.xlsm ${EXTRA:-}; do
    [ -f "$f" ] || continue
    b=$(basename "$f")
    timeout 900 node --no-warnings xlsx_front.mjs survey "$LE2" "$f" > "runs/survey/$b.json" 2> "runs/survey/$b.err"
    echo "$b: exit $?"
done
python3 survey_report.py runs/survey > survey.md
