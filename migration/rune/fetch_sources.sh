#!/bin/sh
# The sources of the Rune door (README.md), in .cache/:
#   - ISDA's Digital Regulatory Reporting (DRR) 7.14.0 from ISDA's public Maven
#     repository: the binary archive (the Rune files, the compiled Java, the
#     test packs) unpacked in .cache/drr, and its Java sources in .cache/drr-java;
#   - the Java libraries DRR runs with (CDM 6.29.0, Rune 9.95.0, ...) in
#     .cache/lib, through Maven (java/pom.xml), and the oracle compiled;
#   - Rune's own sources at the version DRR uses (finos/rune-dsl 9.95.0), read
#     for the semantics of the expressions (rune-runtime's ExpressionOperators);
#   - the Rune files read by cdmLOG's rosetta2json into .cache/json.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
C=$HERE/.cache
mkdir -p "$C"
DRR=7.14.0
M=https://europe-west1-maven.pkg.dev/production-208613/isda-maven/com/regnosys/drr/rosetta-source/$DRR
for f in rosetta-source-$DRR.jar rosetta-source-$DRR-sources.jar; do
  [ -s "$C/$f" ] || curl -sfL -o "$C/$f" "$M/$f"
done
unzip_to() { python3 -c "import sys,zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$1" "$2"; }
[ -d "$C/drr/drr/rosetta" ] || unzip_to "$C/rosetta-source-$DRR.jar" "$C/drr"
[ -d "$C/drr-java/drr" ] || unzip_to "$C/rosetta-source-$DRR-sources.jar" "$C/drr-java"

# DRR's dependencies and the oracle (java/src/main/java/DrrOracle.java)
(cd "$HERE/java" && mvn -q -B -Dmaven.repo.local="$C/m2" dependency:copy-dependencies -DoutputDirectory="$C/lib" \
   && mvn -q -B -Dmaven.repo.local="$C/m2" compile)
CP="$HERE/java/target/classes:$C/rosetta-source-$DRR.jar"
for j in "$C"/lib/*.jar; do CP="$CP:$j"; done
echo "$CP" > "$C/classpath.txt"

# Rune's runtime, for reference
[ -d "$C/rune-dsl" ] || git clone -q --depth 1 --branch 9.95.0 https://github.com/finos/rune-dsl.git "$C/rune-dsl" 2>/dev/null

# The Rune files as JSON (rosetta2json, parser/: a copy of cdmLOG's converter,
# version 0.2.0, maintained beside it; parser/README.md)
R2J=${ROSETTA2JSON:-$HERE/parser/rosetta2json.py}
rm -rf "$C/json"
python3 "$R2J" "$C/drr/drr/rosetta" "$C/json" 2>&1 | grep -v "unrecognized top-level construct: 'schema" || true
