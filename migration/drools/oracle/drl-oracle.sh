#!/bin/sh
# Run the Drools oracle: drl-oracle.sh spec.json  (build first: mvn -q package)
here=$(dirname "$0")
exec java -cp "$here/target/drl-oracle-1.0.jar:$here/target/lib/*" le.drools.DrlOracle "$@"
