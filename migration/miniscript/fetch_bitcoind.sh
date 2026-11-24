#!/bin/sh
# Bitcoin Core (the reference node) for the private regtest backend of the
# chain runs (chain/ms_chain.cjs, NETWORK=regtest): downloaded into .cache/
# (gitignored). The public Tape network needs nothing but node and
# `npm install` in chain/.
set -e
VERSION=${BITCOIN_VERSION:-31.1}
cd "$(dirname "$0")"
mkdir -p .cache
cd .cache
[ -x "bitcoin-$VERSION/bin/bitcoind" ] && { echo "bitcoin-$VERSION already here"; exit 0; }
curl -sL "https://bitcoincore.org/bin/bitcoin-core-$VERSION/bitcoin-$VERSION-x86_64-linux-gnu.tar.gz" -o btc.tgz
tar xzf btc.tgz && rm btc.tgz
echo "bitcoind in $(pwd)/bitcoin-$VERSION/bin"
