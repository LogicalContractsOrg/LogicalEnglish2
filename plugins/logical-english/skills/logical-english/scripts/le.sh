#!/bin/sh
# le.sh — ask a Logical English server, with nothing but curl and python3.
#
#   le.sh examples
#   le.sh details EXAMPLE
#   le.sh verify FILE.le
#   le.sh query FILE.le|EXAMPLE QUERY [--scenario NAME] [--facts "FACT." ...] [--json]
#   le.sh doc
#
# The server is $LE_SERVER, by default https://le2.logicalcontracts.com.
# A QUERY is the name of one of the program's queries, or a question in
# Logical English that fits its templates. A query prints each answer with
# its explanation, one step a line (--json: the server's reply as it is);
# the other commands print the server's JSON.
set -e
SERVER=${LE_SERVER:-https://le2.logicalcontracts.com}
SERVER=${SERVER%/}

post() {  # post PATH: the JSON on standard input, sent to the server
    curl -sS --max-time 300 -X POST "$SERVER/$1" -H 'Content-Type: application/json' --data-binary @-
}

# A query's reply, for a reader: each answer, and under it the steps of its
# explanation, indented as the proof is nested.
SHOW='
import json, sys
d = json.load(sys.stdin)
def show(nodes, depth):
    for n in nodes or []:
        lit = n.get("literal") or n.get("text") or ""
        kind = n.get("type", "")
        mark = {"failure": "not: ", "unknown": "unknown: "}.get(kind, "")
        if lit:
            print("  " * depth + "- " + mark + lit)
        show(n.get("children"), depth + 1 if lit else depth)
if d.get("error"):
    print("error: " + str(d["error"]))
for n in d.get("notes") or []:
    print("NOTE: " + n)
rs = d.get("results") or []
for r in rs:
    print("ANSWER: " + str(r.get("answer")))
    c = r.get("case") or {}
    if c.get("scenario") and not c.get("coveredBy"):
        print("  a scenario that meets this case, ready to add to the program:")
        print("\n".join("    " + l for l in c["scenario"].splitlines()))
    show(r.get("explanation"), 1)
if not rs and not d.get("error"):
    print("NO ANSWER")
    show(d.get("explanation") if isinstance(d.get("explanation"), list) else [], 1)
'

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

[ $# -ge 1 ] || usage
cmd=$1; shift
case $cmd in
    examples)
        curl -sS --max-time 120 "$SERVER/list_examples" | python3 -c '
import json, sys
for e in json.load(sys.stdin).get("examples", []):
    print(e["name"] + ": " + (e.get("summary") or "").replace("\n", " ")[:160])'
        ;;
    details)
        [ $# -eq 1 ] || usage
        python3 -c 'import json, sys; print(json.dumps({"example_name": sys.argv[1]}))' "$1" | post example_details
        ;;
    verify)
        [ $# -eq 1 ] || usage
        python3 -c 'import json, sys; print(json.dumps({"program_text": open(sys.argv[1], encoding="utf-8").read()}))' "$1" | post verify
        ;;
    query)
        [ $# -ge 2 ] || usage
        RAW=no
        for a in "$@"; do [ "$a" = --json ] && RAW=yes; done
        python3 - "$@" <<'PY' | post query | if [ $RAW = yes ]; then cat; else python3 -c "$SHOW"; fi
import json, os, sys
program, query, rest = sys.argv[1], sys.argv[2], sys.argv[3:]
args = {"query": query}
if os.path.isfile(program):
    args["program_text"] = open(program, encoding="utf-8").read()
else:
    args["example_name"] = program
facts = []
i = 0
while i < len(rest):
    if rest[i] == "--json":
        i += 1
    elif rest[i] == "--scenario" and i + 1 < len(rest):
        args["scenario_name"] = rest[i + 1]; i += 2
    elif rest[i] == "--facts":
        i += 1
        while i < len(rest) and not rest[i].startswith("--"):
            facts.append(rest[i]); i += 1
    else:
        sys.exit("le.sh: unexpected argument " + rest[i])
if facts:
    args["facts"] = "\n".join(facts)
print(json.dumps(args))
PY
        ;;
    doc)
        curl -sS --max-time 120 "$SERVER/docs/user/reference/language.md"
        ;;
    *)
        usage
        ;;
esac
