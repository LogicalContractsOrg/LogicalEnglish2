#!/bin/sh
# The phase-0 survey over the harvested corpus (harvest_corpus.py): one JSON
# per workbook in runs/survey_corpus, the table in survey_corpus.md.
cd "$(dirname "$0")"
LE2=${LE2_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}
mkdir -p runs/survey_corpus
for f in .cache/corpus/*.xlsx; do
    b=$(basename "$f")
    timeout 300 node --no-warnings xlsx_front.mjs survey "$LE2" "$f" > "runs/survey_corpus/$b.json" 2> "runs/survey_corpus/$b.err"
done
python3 survey_report.py runs/survey_corpus > survey_corpus.md
