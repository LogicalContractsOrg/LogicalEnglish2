#!/bin/sh
# DRR's own Java run on the instructions of a test pack (README.md, the oracle):
#   oracle.sh <report> <function class>
#   oracle.sh cftc-part45 drr.regulation.cftc.rewrite.trade.reports.CFTCPart45ReportFunction
# writes .cache/oracle/<report>/<group>/<name>.json, one report per instruction
# whose expected report is in the archive, and compares them with the archive.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
C=$HERE/.cache
P=fpml-record-keeping-to-reportable-event/transaction-report-instruction-test-pack-default
REPORT=$1; FN=$2; IN=${3:-drr.regulation.common.TransactionReportInstruction}
EXP=$C/drr/regulatory-reporting/output/$P/$REPORT
mkdir -p "$C/oracle"
find "$EXP" -name '*.json' | sort | while read e; do
  r=${e#$EXP/}
  printf '%s\t%s\n' "$C/drr/enrich/output/$P/$r" "$C/oracle/$REPORT/$r"
done > "$C/oracle/$REPORT.pairs"
java -cp "$(cat "$C/classpath.txt")" DrrOracle "$FN" "$IN" < "$C/oracle/$REPORT.pairs" 2>/dev/null \
  | cut -f1 | sort | uniq -c
python3 "$HERE/flat.py" compare "$EXP" "$C/oracle/$REPORT"
