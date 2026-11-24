#!/bin/sh
# The four DMN collections at the commits corpus.pl pins, into .cache/
# (gitignored), and the bruidsschat's STTR files of the final July 2023
# release unpacked into .cache/sttr. Then the oracle: oracle/build.sh
# (Apache KIE Drools 10.2.0, Maven and Java 21).
set -e
cd "$(dirname "$0")"
mkdir -p .cache
fetch() {   # dir url id
    commit=$(swipl -q -g "use_module(corpus), dmn_corpus:source_commit($3, _, C), write(C), halt.")
    if [ ! -d ".cache/$1/.git" ]; then
        git -c safe.directory='*' init -q ".cache/$1"
        git -c safe.directory='*' -C ".cache/$1" remote add origin "$2"
    fi
    if [ "$(git -c safe.directory='*' -C ".cache/$1" rev-parse HEAD 2>/dev/null)" != "$commit" ]; then
        git -c safe.directory='*' -C ".cache/$1" fetch -q --depth 1 origin "$commit"
        git -c safe.directory='*' -C ".cache/$1" -c advice.detachedHead=false checkout -q FETCH_HEAD
    fi
    echo "$1 at $(git -c safe.directory='*' -C ".cache/$1" rev-parse --short HEAD)"
}
fetch tck https://github.com/dmn-tck/tck.git tck
fetch bruidsschat https://gitlab.com/koop/PR04/bruidsschat-teruglevering.git bruidsschat
fetch ronl https://github.com/sgort/linked-data-explorer.git ronl
fetch bdt https://github.com/CodeForPhilly/benefit-decision-toolkit.git bdt
# The client examples' models: single files at the pinned commits.
swipl -q -g "use_module(corpus), forall(dmn_corpus:client_file(R, P, F), (dmn_corpus:source_commit(R, U, C), format('~w|~w|~w|~w~n', [U, C, P, F]))), halt." |
while IFS='|' read -r url commit path file; do
    raw=$(echo "$url" | sed -e 's#https://github.com/#https://raw.githubusercontent.com/#' -e 's#\.git$##')
    mkdir -p ".cache/clients/$(dirname "$file")"
    curl -sfL -o ".cache/clients/$file" "$raw/$commit/$(echo "$path" | sed 's/ /%20/g')"
    echo "clients: $file"
done
python3 - <<'PY'
import zipfile, os
base = ".cache/bruidsschat/Toepasbare Regels Bruidsschat/03 STTR-bestanden – juli 2023 (finale oplevering)"
for z, out in [("sttr-gemeentes.zip", "gemeenten"), ("sttr-waterschappen.zip", "waterschappen")]:
    zipfile.ZipFile(os.path.join(base, z)).extractall(os.path.join(".cache/sttr", out))
print("sttr:", sum(len(f) for _, _, f in os.walk(".cache/sttr")), "files")
PY
