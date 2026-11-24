#!/bin/sh
# Builds target/camunda-dmn-oracle.jar with a Maven repository local to this folder (.m2, gitignored).
set -e
cd "$(dirname "$0")"
export MAVEN_OPTS="${MAVEN_OPTS:--Xmx1g}"
mvn -q -B -Dmaven.repo.local="$PWD/.m2" package "$@"
ls -l target/camunda-dmn-oracle.jar
