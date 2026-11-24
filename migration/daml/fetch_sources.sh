#!/bin/sh
# The Daml SDK's own templates (Apache-2.0), the corpus of the Daml twins,
# created with the SDK's `dpm new` into .cache/ (gitignored). Needs the Daml
# SDK (dpm 3.5.x: https://docs.digitalasset.com; ~/.dpm/bin/dpm).
set -e
cd "$(dirname "$0")"
DPM=${DPM:-$HOME/.dpm/bin/dpm}
mkdir -p .cache
for t in skeleton quickstart-java daml-intro-contracts daml-intro-choices daml-intro-constraints \
         daml-intro-parties daml-intro-daml-scripts daml-intro-compose daml-patterns; do
  [ -d .cache/$t ] || (cd .cache && "$DPM" new "$t" --template "$t" >/dev/null)
done
ls .cache
