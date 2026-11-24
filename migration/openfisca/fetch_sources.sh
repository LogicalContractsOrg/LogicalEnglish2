#!/bin/sh
# OpenFisca's country template and PolicyEngine's US and UK packages
# (AGPL-3.0) at the commits corpus.pl pins, into .cache/ (gitignored), and a
# Python environment, .cache/venv, with each package installed (and with it
# its engine, openfisca-core or policyengine-core) for of_extract.py and
# of_oracle.py.
set -e
cd "$(dirname "$0")"
mkdir -p .cache
sed -n "s/^repo_commit('\([^']*\)', '\([^']*\)', '\([0-9a-f]*\)').*/\1 \2 \3/p" corpus.pl | while read name url commit; do
    if [ ! -d .cache/$name/.git ]; then
        git -c safe.directory=* init -q .cache/$name
        git -c safe.directory=* -C .cache/$name remote add origin $url
    fi
    if [ "$(git -c safe.directory=* -C .cache/$name rev-parse HEAD 2>/dev/null)" != "$commit" ]; then
        git -c safe.directory=* -C .cache/$name fetch -q --depth 1 origin $commit
        git -c safe.directory=* -C .cache/$name -c advice.detachedHead=false checkout -q FETCH_HEAD
    fi
    echo "$name at $(git -c safe.directory=* -C .cache/$name rev-parse --short HEAD)"
done
[ -x .cache/venv/bin/python ] || python3 -m venv .cache/venv
#  One environment per engine: pip will not resolve openfisca-core 45 (what
#  PolicyEngine asks for) together with openfisca-country-template 8.1.0,
#  which pins another core, and openfisca-france needs core 44. PyYAML is for
#  of_roundtrip_run.py.
.cache/venv/bin/pip install -q PyYAML -e .cache/policyengine-us -e .cache/policyengine-uk
[ -d .cache/venv-ct ] || python3 -m venv .cache/venv-ct
.cache/venv-ct/bin/pip install -q PyYAML -e .cache/country-template
