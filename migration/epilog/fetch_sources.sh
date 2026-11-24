#!/bin/sh
# The Epilog sources of the twins, into .cache/ (gitignored), from the Epilog
# site (http://epilog.stanford.edu):
#   - the EpilogJS interpreter (Stanford's; for academic, non-commercial use
#     only, and not to be redistributed — see README), the oracle;
#   - every rule sheet and data sheet the Examples page links to;
#   - the Epilog program (`library`) and data (`lambda`) of each worksheet the
#     Examples page links to (Game of Life, Portico, Schedule, Solar System);
#   - the library of every game of the Games page.
# The lists are read from the pages, so a new example on the site is fetched
# too. The twins keep the text they were built from under their sources/.
set -e
cd "$(dirname "$0")"
mkdir -p .cache/theories .cache/games .cache/worksheets
B=http://epilog.stanford.edu
curl -sL $B/javascript/epilog.js -o .cache/epilog.js
curl -sL $B/homepage/examples.php -o .cache/examples.html
for t in $(grep -o "rulesheet.php?theory=[a-z0-9]*" .cache/examples.html | sed 's/.*=//' | sort -u); do
  curl -sL "$B/homepage/rulesheet.php?theory=$t" -o .cache/theories/$t.rules
done
for t in $(grep -o "datasheet.php?theory=[a-z0-9]*" .cache/examples.html | sed 's/.*=//' | sort -u); do
  curl -sL "$B/homepage/datasheet.php?theory=$t" -o .cache/theories/$t.data
done
for w in $(grep -o "\.\./examples/[a-z0-9]*/\(worksheet\|solution\|index\)\.html" .cache/examples.html | sort -u); do
  id=$(echo "$w" | cut -d/ -f3)
  curl -sL "$B/${w#../}" -o .cache/worksheets/$id.html
  python3 - "$id" <<'PY'
import re, html, sys
w = sys.argv[1]
s = open(f'.cache/worksheets/{w}.html', encoding='utf8', errors='replace').read()
for name, ext in (('library', 'hrf'), ('lambda', 'data')):
    m = re.search(r"<textarea[^>]*id=.%s.[^>]*>(.*?)</textarea>" % name, s, re.S)
    if m:
        open(f'.cache/worksheets/{w}.{ext}', 'w').write(html.unescape(m.group(1)))
PY
done
curl -sL $B/homepage/games.php -o .cache/games.html
for g in $(grep -o "game.php?game=[a-z0-9]*" .cache/games.html | sed 's/.*=//' | sort -u); do
  curl -sL "$B/homepage/game.php?game=$g" -o .cache/games/$g.html
  python3 - "$g" <<'PY'
import re, html, sys
g = sys.argv[1]
s = open(f'.cache/games/{g}.html', encoding='utf8', errors='replace').read()
m = re.search(r"id=.library.[^>]*>(.*?)</textarea>", s, re.S)
if m:
    open(f'.cache/games/{g}.hrf', 'w').write(html.unescape(m.group(1)))
PY
done
