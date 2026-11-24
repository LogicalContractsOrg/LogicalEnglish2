#!/bin/sh
# The fact model of the Drools examples (corpus/java, Apache License 2.0),
# compiled into model/ for the oracle (gitignored).
cd "$(dirname "$0")"
mkdir -p model
javac -d model $(find corpus/java -name '*.java')
