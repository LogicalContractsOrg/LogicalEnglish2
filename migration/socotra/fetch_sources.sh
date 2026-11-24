#!/bin/bash
# Fetches the Socotra sources the reader translates into sources/.cache/.
#
#   socotra/product-library  the 17 product configurations (pinned commit).
#                            NO licence file: the twins generated from it, and
#                            the copies of each product's configuration files
#                            beside them (sources/, for the editors' Show the
#                            Original), are kept in this private repository and
#                            not published until its licence is confirmed.
#   socotra/public           MIT (its README); fetched for reference only (the
#                            premium_test harness the oracle's shims follow).
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
