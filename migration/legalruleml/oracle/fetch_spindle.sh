#!/bin/sh
# Fetches SPINdle 2.2.4 (the defeasible deontic logic reasoner of
# H.-P. Lam and G. Governatori; copyright 2009-2014 NICTA Ltd.; GNU Lesser
# General Public License, version 3) into oracle/spindle/, where
# lrml_spindle.pl looks for it (or set SPINDLE_JAR). Needs Java 6+.
# SPINdle is run as a separate program and is not part of this repository
# (oracle/.gitignore keeps the download out of git).
set -e
cd "$(dirname "$0")"
mkdir -p spindle
curl -sL -o spindle/spindle_bin.zip \
  "https://downloads.sourceforge.net/project/spindlereasoner/2.2.4/spindle_bin__2.2.4.zip"
python3 -c "import zipfile; zipfile.ZipFile('spindle/spindle_bin.zip').extractall('spindle')"
rm spindle/spindle_bin.zip
ls spindle/SPINdle_2.2.4/dist/spindle_2.2.4.jar
