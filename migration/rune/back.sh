#!/bin/sh
# The way back (README.md, step 6): a reporting rule written in Logical English
# becomes Rune (le_to_rune.pl), Java by DRR's own tools (java_back/RuneBack.java,
# Rune 9.95's generator), and runs with DRR's Java on the instructions of a test
# pack (DrrOracle); its values are compared with a field of DRR's own report.
#
#   back.sh <LE file> <template prefix> <Rune name> <report> <field>
#   back.sh <private twins>/examples/migration/rune/fca_ukemir_trade/back_confirmed.le \
#           'the UK confirmed written in LE' ConfirmedFromLE fca-ukemir-trade confirmed
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
C=$HERE/.cache
LE=$1; PREFIX=$2; NAME=$3; REPORT=$4; FIELD=$5
B=$C/back/$NAME
rm -rf "$B"; mkdir -p "$B/gen" "$B/classes" "$B/out"
CP="$(ls $C/lib/*.jar | tr '\n' ':')"

# 1. Logical English -> Rune
(cd "${LE2_DIR:-$HERE/../..}" && ./myswipl.sh -q "$HERE/le_to_rune_cli.pl" -- "$LE" none "$PREFIX" "$NAME" "$B/$NAME.rosetta")

# 2. Rune -> Java, by Rune's generator, with DRR's and the CDM's Rune loaded
javac -nowarn -cp "$HERE/java_back:$CP" -d "$HERE/java_back/classes" "$HERE/java_back/RuneBack.java"
java -Xmx6g -cp "$HERE/java_back/resources:$HERE/java_back/classes:$CP" RuneBack "$B/gen" \
  $C/lib/rune-runtime-9.95.0.jar $C/lib/cdm-java-6.29.0.jar $C/lib/rosetta-source-1.46.0.jar \
  $C/lib/rosetta-source-2.9.0.jar $C/lib/rosetta-source-7.14.0.jar -- "$B/$NAME.rosetta" 2>&1 | grep -v '^SLF4J'
find "$B/gen" -name '*.java' > "$B/sources.txt"
javac -nowarn -cp "$CP" -d "$B/classes" @"$B/sources.txt"

# 3. DRR's Java runs it on the test pack's instructions
P=fpml-record-keeping-to-reportable-event/transaction-report-instruction-test-pack-default
EXP=$C/drr/regulatory-reporting/output/$P/$REPORT
find "$EXP" -name '*.json' | sort | while read e; do
  r=${e#$EXP/}
  printf '%s\t%s\n' "$C/drr/enrich/output/$P/$r" "$B/out/$r"
done > "$B/pairs.txt"
CLS=$(sed -n 's|.*/gen/\(.*\)\.java$|\1|p' "$B/sources.txt" | grep 'Rule$' | head -1 | tr '/' '.')
(cd $C && java -cp "$B/classes:$(cat classpath.txt)" DrrOracle "$CLS" drr.regulation.common.TransactionReportInstruction < "$B/pairs.txt" 2>/dev/null | cut -f1 | sort | uniq -c)

# 4. its values against DRR's own field
python3 - "$EXP" "$B/out" "$FIELD" <<'EOF'
import json, os, sys
exp, out, field = sys.argv[1:]
same = differ = 0
for d, _, fs in os.walk(exp):
    for f in sorted(fs):
        e = json.load(open(os.path.join(d, f)))
        o = os.path.join(out, os.path.relpath(os.path.join(d, f), exp))
        v = json.load(open(o)) if os.path.exists(o) else None
        if v == {}: v = None
        w = e.get(field)
        if v == w: same += 1
        else:
            differ += 1
            print('  differs:', os.path.relpath(o, out), 'LE rule:', v, 'DRR:', w)
print(f'{same} of {same + differ} instructions: the rule written in LE gives DRR\'s own {field}')
EOF
