#!/bin/bash
# Fetches the Socotra sources the reader translates into sources/.cache/.
#
#   socotra/product-library  the 17 product configurations (pinned commit).
#                            NO licence file: the twins generated from it, and
#                            the copies of each product's configuration files
#                            beside them (sources/, for the editors' Show the
#                            Original), are written to a private place
#                            (../le2_paths.pl, private_root/1) and are not
#                            published.
#   socotra/public           MIT (the licence text is in its README, Copyright
#                            (c) 2022 Socotra); fetched for reference only (the
#                            premium_test harness the oracle's shims follow).
#                            Nothing of it is copied into this repository.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cache="$here/sources/.cache"
mkdir -p "$cache"

fetch() {   # repo dir commit
    local repo=$1 dir=$2 commit=$3
    if [ ! -d "$cache/$dir/.git" ]; then
        git clone --quiet "https://github.com/$repo.git" "$cache/$dir"
    fi
    git -C "$cache/$dir" fetch --quiet origin || true
    git -C "$cache/$dir" -c advice.detachedHead=false checkout --quiet "$commit"
    echo "$repo @ $(git -C "$cache/$dir" rev-parse --short HEAD) -> sources/.cache/$dir"
}

fetch socotra/product-library product-library df4a7f851ac6e3a79ecf6b2c007d75bd6c22c9e8
fetch socotra/public          public          d3e6142fdb684805c1110bb86052e5376d918731
