#!/bin/sh
# The way back, run (the design notes rune.md §13): a Rune file written by
# rune_export.pl is compiled by Rune's own generator with DRR and the CDM
# loaded (java_back/RuneBack.java), and its report function runs, with DRR's
# Java, on the instructions of the report's test pack; each report is then
# compared with DRR's expected one, field by field.
#
#   run_back.sh <file.rosetta>        (beside it: <file>.pairs.txt, <file>.expected.txt)
#
# Prints the validator's issues, then "N of M reports are DRR's own; F field
# values agree, D differ" and the fields that differ.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
C=$HERE/.cache
R=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
B=${R%.rosetta}.build
rm -rf "$B" "$R.out"; mkdir -p "$B/gen" "$B/classes" "$R.out"
CP="$(ls $C/lib/*.jar | tr '\n' ':')"

# 1. Rune -> Java, by Rune's generator
[ -f "$HERE/java_back/classes/RuneBack.class" ] || javac -nowarn -cp "$HERE/java_back:$CP" -d "$HERE/java_back/classes" "$HERE/java_back/RuneBack.java"
java -Xmx6g -cp "$HERE/java_back/resources:$HERE/java_back/classes:$CP" RuneBack "$B/gen" \
  $C/lib/rune-runtime-9.95.0.jar $C/lib/cdm-java-6.29.0.jar $C/lib/rosetta-source-1.46.0.jar \
  $C/lib/rosetta-source-2.9.0.jar $C/lib/rosetta-source-7.14.0.jar -- "$R" 2>&1 | grep -v '^SLF4J' | grep -v '^loaded\|^resolved\|^generated' || true
find "$B/gen" -name '*.java' > "$B/sources.txt"
[ -s "$B/sources.txt" ] || { echo "Rune's generator wrote nothing: the file has errors"; exit 1; }
javac -nowarn -cp "$CP" -d "$B/classes" @"$B/sources.txt"

# 2. DRR's Java runs the report function on the test pack
CLS=$(sed -n 's|.*/gen/\(.*ReportFunction\)\.java$|\1|p' "$B/sources.txt" | head -1 | tr '/' '.')
IN=$(sed -n 's/^    from \(.*\)$/\1/p' "$R" | tail -1)
(cd "$C" && java -cp "$B/classes:$(cat classpath.txt)" DrrOracle "$CLS" "$IN" < "${R}.pairs.txt" 2>/dev/null | cut -f1 | sort | uniq -c | sed 's/^/  run: /')

# 3. each report against DRR's expected one
python3 - "${R}.expected.txt" <<'PY'
import json, os, sys, collections
def flat(x, p=''):
    out = {}
    if isinstance(x, dict):
        for k, v in x.items(): out.update(flat(v, f'{p}.{k}' if p else k))
    elif isinstance(x, list):
        for i, v in enumerate(x): out.update(flat(v, f'{p}[{i}]'))
    else: out[p] = x
    return out
same = n = agree = differ = 0
fields = collections.Counter()
for line in open(sys.argv[1]):
    o, e = line.rstrip('\n').split('\t')
    n += 1
    fe = flat(json.load(open(e)))
    fo = flat(json.load(open(o))) if os.path.exists(o) else {}
    d = [k for k in set(fe) | set(fo) if fe.get(k) != fo.get(k)]
    agree += sum(1 for k in fe if fe.get(k) == fo.get(k)); differ += len(d)
    same += not d
    for k in d: fields[k.split('[')[0]] += 1
print(f'{same} of {n} reports are DRR\'s own; {agree} field values agree, {differ} differ')
for k, c in fields.most_common(15): print(f'  {c:4d}  {k}')
PY
