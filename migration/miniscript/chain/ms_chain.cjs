#!/usr/bin/env node
/*  Spending attempts of a Miniscript policy, run on a real Bitcoin chain.

    The chain half of the Miniscript twins' fidelity check (README, "On a
    chain"): the twin's scenarios say which witnesses spend the coin; this
    tool puts the same witnesses in front of Bitcoin Core's own script
    interpreter and records what the chain says. It knows nothing about
    Logical English — ms_chain.pl writes the attempts and turns the record
    into scenarios.

        node ms_chain.cjs compile '<policy>'        policy -> Miniscript (sipa's compiler)
        node ms_chain.cjs material <spec.json>      the test keys and hashes of the spec's names
        node ms_chain.cjs run <spec.json>           the attempts, on the spec's network

    A spec: { network: "tape" | "regtest", policy: "and(pk(K1),older(10))",
              miniscript: "and_v(v:pk(K1),older(10))" (optional: as written, not compiled),
              keys: {K1: "the user", ...}, hashes: {H1: {kind: "sha256", name: ...}},
              confirmations: n (regtest: blocks mined over each coin),
              attempts: [{id, have: {sigs: [K1], preimages: [H1]},
                          path: {sigs: [...], preimages: [...]}}] }

    Keys and hashes are the policy's placeholders. The keys the chain sees
    are TEST keys derived from each role's name (sha256 of "LE Miniscript
    test key: <role>"), and each hash is the hash of a test preimage: the
    policy's structure is the source's, its keys are not (nobody holds the
    source's private keys). An attempt is the material a spender has — the
    signatures and preimages — and the tool does what a wallet does: it
    asks the Miniscript satisfier for a witness made of that material
    (one without locks first, else the one with the smallest lock), sets
    the input's nSequence for a relative lock and the transaction's
    nLockTime for an absolute one, signs and broadcasts. Whether the coin
    is old enough, or the lock time final, is the chain's business. When
    the material makes no witness at all, the attempt offers the witness of
    the spending path it was cut from (`path`) with the missing parts left
    out — an empty push for a signature, a wrong preimage for a hash — so
    the chain still judges a transaction.

    Networks:
      tape     RewindBitcoin's Tape test chain (run by its operator on one
               node and open to the public: regtest addresses, a faucet and
               an Esplora API): https://tape.rewindbitcoin.com — the default.
               Its faucet is a courtesy of its operator: one coin per twin,
               at most two requests a minute.
      regtest  a private bitcoind started by this tool (BITCOIND=path to
               the binary; the bitcoind under ../.cache by default):
               blocks are mined on demand, so relative locks can be met.

    The record (stdout, JSON): the descriptor, the address, the funding
    transaction, and per attempt the verdict (`accepted` with the txid,
    `refused` with the node's reason), the chain height, the block the
    coin was confirmed in (null while unconfirmed) and the nSequence /
    nLockTime the transaction carried.
*/
'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawn, execFileSync } = require('child_process');
const bitcoin = require('bitcoinjs-lib');
const ecc = require('@bitcoinerlab/secp256k1');
const { ECPairFactory } = require('ecpair');
const { Output } = require('@bitcoinerlab/descriptors');
const { satisfier } = require('@bitcoinerlab/miniscript');
const policies = require('@bitcoinerlab/miniscript-policies');

const ECPair = ECPairFactory(ecc);
const NETWORK = bitcoin.networks.regtest;          // Tape uses regtest addresses
const TAPE = 'https://tape.rewindbitcoin.com';
const FEE = 1000n;
const sha256 = (b) => crypto.createHash('sha256').update(b).digest();
const hex = (b) => Buffer.from(b).toString('hex');

/*  Test material, reproducible from the names alone. */
function testKey(role) {
    return ECPair.fromPrivateKey(sha256(Buffer.from('LE Miniscript test key: ' + role)), { network: NETWORK });
}
function testPreimage(name) { return sha256(Buffer.from('LE Miniscript test preimage: ' + name)); }
function hashOf(kind, pre) {
    switch (kind) {
        case 'sha256': return bitcoin.crypto.sha256(pre);
        case 'hash256': return bitcoin.crypto.hash256(pre);
        case 'ripemd160': return bitcoin.crypto.ripemd160(pre);
        case 'hash160': return bitcoin.crypto.hash160(pre);
        default: throw new Error('unknown hash kind ' + kind);
    }
}

/*  Placeholders are replaced whole-word, longest first. */
function substitute(text, table) {
    const names = Object.keys(table).sort((a, b) => b.length - a.length);
    for (const n of names) text = text.replace(new RegExp('\\b' + n + '\\b', 'g'), table[n]);
    return text;
}

async function compile(policy) {
    await policies.ready;
    return policies.compilePolicy(policy);
}

/*  ---------------------------------------------------------------- backends */

function esplora(base) {
    const api = base + '/api';
    return {
        name: base,
        async tip() { return Number(await (await fetch(api + '/blocks/tip/height')).text()); },
        async fund(address) {
            const r = await fetch(base + '/faucet', {
                method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: new URLSearchParams({ address }).toString()
            });
            const t = await r.text();
            let j = null; try { j = JSON.parse(t); } catch {}
            if (j && j.ok && j.info !== 'CACHED') return j.txId;
            if (this.retries === undefined) this.retries = 0;
            if (this.retries++ < 8) { await sleep(35000); return this.fund(address); }   // 2 requests a minute
            throw new Error('the faucet refused: ' + t.slice(0, 200));
        },
        async txHex(txid) {
            for (let i = 0; i < 30; i++) {
                const r = await fetch(api + '/tx/' + txid + '/hex');
                if (r.ok) return await r.text();
                await sleep(2000);
            }
            throw new Error('transaction ' + txid + ' not found');
        },
        async confirmedAt(txid) {
            const r = await fetch(api + '/tx/' + txid + '/status');
            if (!r.ok) return null;
            const s = await r.json();
            return s.confirmed ? s.block_height : null;
        },
        async blockTime(height) {
            const h = await (await fetch(api + '/block-height/' + height)).text();
            return (await (await fetch(api + '/block/' + h)).json()).mediantime;
        },
        async broadcast(txHex) {
            const r = await fetch(api + '/tx', { method: 'POST', body: txHex });
            const t = await r.text();
            return r.ok ? { accepted: true, txid: t.trim() } : { accepted: false, reason: t.trim() };
        },
        explorer: (txid) => base + '/explorer/tx/' + txid,
        async close() {}
    };
}

function bitcoind() {
    const bin = process.env.BITCOIND || defaultBitcoind();
    const cli = path.join(path.dirname(bin), 'bitcoin-cli');
    const dir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'ms-regtest-'));
    const port = 18000 + Math.floor(Math.random() * 2000);
    const args = ['-regtest', '-datadir=' + dir, '-rpcport=' + port, '-port=' + (port + 1),
                  '-rpcuser=le', '-rpcpassword=le', '-fallbackfee=0.0001', '-txindex=1', '-listen=0'];
    const proc = spawn(bin, args, { stdio: 'ignore' });
    const rpc = (...a) => execFileSync(cli, ['-regtest', '-datadir=' + dir, '-rpcport=' + port,
                                             '-rpcuser=le', '-rpcpassword=le', ...a]).toString().trim();
    let miner = null;
    const b = {
        name: 'a private regtest bitcoind',
        async start() {
            for (let i = 0; i < 60; i++) { try { execFileSync(cli, ['-regtest', '-datadir=' + dir, '-rpcport=' + port, '-rpcuser=le', '-rpcpassword=le', 'getblockcount'], { stdio: 'ignore' }); break; } catch { await sleep(500); } }
            rpc('createwallet', 'faucet');
            miner = rpc('getnewaddress', '', 'bech32');
            rpc('generatetoaddress', '101', miner);
        },
        async tip() { return Number(rpc('getblockcount')); },
        async fund(address) { return rpc('sendtoaddress', address, '0.1'); },
        async txHex(txid) { return rpc('getrawtransaction', txid); },
        async confirmedAt(txid) {
            const t = JSON.parse(rpc('getrawtransaction', txid, 'true'));
            if (!t.blockhash) return null;
            return JSON.parse(rpc('getblockheader', t.blockhash)).height;
        },
        async blockTime(height) { return JSON.parse(rpc('getblockheader', rpc('getblockhash', String(height)))).mediantime; },
        async broadcast(txHex) {
            try { return { accepted: true, txid: rpc('sendrawtransaction', txHex) }; }
            catch (e) { return { accepted: false, reason: String(e.stderr || e.message).trim() }; }
        },
        async mine(n) { rpc('generatetoaddress', String(n), miner); },
        explorer: () => null,
        async close() { try { rpc('stop'); } catch {} await sleep(1500); proc.kill(); fs.rmSync(dir, { recursive: true, force: true }); }
    };
    return b;
}

function defaultBitcoind() {
    const cache = path.join(__dirname, '..', '.cache');
    const d = fs.existsSync(cache) ? fs.readdirSync(cache).find((x) => x.startsWith('bitcoin-')) : null;
    if (!d) throw new Error('no bitcoind: set BITCOIND or run fetch_bitcoind.sh');
    return path.join(cache, d, 'bin', 'bitcoind');
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/*  ---------------------------------------------------------------- witnesses */

/*  The witness a wallet builds from the material it has: the satisfier's
    solutions (non-malleable first) made of those signatures and preimages,
    one without locks first, else the one with the smallest lock. */
function knownsOf(have, keysHex, hashesHex) {
    return [...(have.sigs || []).map((k) => `<sig(${keysHex[k]})>`),
            ...(have.preimages || []).map((h) => `<${hashesHex[h].kind}_preimage(${hashesHex[h].hash})>`)];
}
function solutions(ms, have, keysHex, hashesHex) {
    const knowns = knownsOf(have, keysHex, hashesHex);
    try {
        const r = knowns.length ? satisfier(ms, { knowns }) : satisfier(ms, { unknowns: allUnknowns(ms) });
        return [...r.nonMalleableSats, ...r.malleableSats];
    } catch (e) { return []; }
}
function allUnknowns(ms) {
    const u = new Set();
    for (const m of ms.matchAll(/pkh?\((\w+)\)|multi(?:_a)?\(\d+,([\w,]+)\)/g)) {
        if (m[1]) u.add(`<sig(${m[1]})>`); else m[2].split(',').forEach((k) => u.add(`<sig(${k})>`));
    }
    for (const m of ms.matchAll(/(sha256|hash256|ripemd160|hash160)\((\w+)\)/g)) u.add(`<${m[1]}_preimage(${m[2]})>`);
    return [...u];
}
function lockRank(s) { return [s.nSequence === undefined && s.nLockTime === undefined ? 0 : 1, s.nSequence || 0, s.nLockTime || 0]; }
function bestSolution(sols) {
    return sols.slice().sort((a, b) => {
        const x = lockRank(a), y = lockRank(b);
        return x[0] - y[0] || x[1] - y[1] || x[2] - y[2];
    })[0] || null;
}

async function run(spec) {
    await policies.ready;
    const net = spec.network || 'tape';
    const chain = net === 'regtest' ? bitcoind() : esplora(net === 'tape' ? TAPE : net);
    if (chain.start) await chain.start();
    try {
        /* the policy with test keys and hashes */
        const keysHex = {}, signers = {};
        for (const [k, role] of Object.entries(spec.keys || {})) {
            const kp = testKey(role); signers[k] = kp; keysHex[k] = hex(kp.publicKey);
        }
        const hashesHex = {}, preimages = {};
        for (const [h, { kind, name }] of Object.entries(spec.hashes || {})) {
            const pre = testPreimage(name || h); preimages[h] = pre;
            hashesHex[h] = { kind, hash: hex(hashOf(kind, pre)) };
        }
        const table = { ...keysHex };
        for (const [h, v] of Object.entries(hashesHex)) table[h] = v.hash;
        //  sipa's compiler reads a hash only as hex (or its demo name H)
        const hashTable = Object.fromEntries(Object.entries(hashesHex).map(([h, v]) => [h, v.hash]));
        const compiled = spec.miniscript ? { miniscript: spec.miniscript, issane: true }
                                         : policies.compilePolicy(substitute(spec.policy, hashTable));
        if (!compiled.issane) throw new Error('the policy does not compile to sane Miniscript: ' + compiled.miniscript);
        const ms = substitute(compiled.miniscript, table);
        const descriptor = `wsh(${ms})`;
        const out = new Output({ descriptor, network: NETWORK });
        const address = out.getAddress();
        const witnessScript = out.getWitnessScript();
        const scriptPubKey = out.getScriptPubKey();

        /* the coin: on a public chain one faucet coin, which each accepted
           spend pays back to the policy (so the next attempt spends that);
           on a private regtest one coin per attempt, all of them buried
           under `confirmations` blocks, so relative locks can be met */
        const coinOf = async (txid) => {
            const t = bitcoin.Transaction.fromHex(await chain.txHex(txid));
            const vout = t.outs.findIndex((o) => hex(o.script) === hex(scriptPubKey));
            return { txid, vout, value: BigInt(t.outs[vout].value) };
        };
        const fundingTxid = await chain.fund(address);
        let coin = await coinOf(fundingTxid);
        const own = [];
        if (chain.mine) {
            for (let i = 1; i < spec.attempts.length; i++) own.push(await coinOf(await chain.fund(address)));
            await chain.mine(Math.max(1, spec.confirmations || 1));
        }

        const results = [];
        for (const [i, a] of spec.attempts.entries()) {
            const r = { id: a.id };
            if (chain.mine && i > 0) coin = own[i - 1];
            let sat = bestSolution(solutions(ms, a.have, keysHex, hashesHex));
            let withheldSigs = new Set(), withheldPres = new Set();
            r.witness = 'made of the material';
            if (!sat) {                          // no witness: the path's, with the missing parts left out
                sat = bestSolution(solutions(ms, a.path, keysHex, hashesHex));
                if (!sat) { r.verdict = 'not_attempted'; r.reason = 'no witness for the path'; results.push(r); continue; }
                withheldSigs = new Set(a.path.sigs.filter((k) => !(a.have.sigs || []).includes(k)));
                withheldPres = new Set(a.path.preimages.filter((h) => !(a.have.preimages || []).includes(h)));
                r.witness = 'the path\'s, with what is missing left out';
            }
            const tip = await chain.tip();
            const tx = new bitcoin.Transaction();
            tx.version = 2;
            tx.locktime = sat.nLockTime || 0;
            tx.addInput(Buffer.from(coin.txid, 'hex').reverse(), coin.vout,
                        sat.nSequence !== undefined ? sat.nSequence : (sat.nLockTime ? 0xfffffffe : 0xfffffffd));
            tx.addOutput(scriptPubKey, coin.value - FEE);
            const sighash = tx.hashForWitnessV0(0, witnessScript, coin.value, bitcoin.Transaction.SIGHASH_ALL);
            const byHexKey = Object.fromEntries(Object.entries(keysHex).map(([k, v]) => [v, k]));
            const byHash = Object.fromEntries(Object.entries(hashesHex).map(([h, v]) => [v.hash, h]));
            const used = { sigs: [], preimages: [] };
            const stack = sat.asm.split(' ').filter((t) => t).map((tok) => {
                let m;
                if ((m = tok.match(/^<sig\((\w+)\)>$/))) {
                    const k = byHexKey[m[1]];
                    if (withheldSigs.has(k)) return Buffer.alloc(0);
                    used.sigs.push(k);
                    return Buffer.from(bitcoin.script.signature.encode(signers[k].sign(sighash), bitcoin.Transaction.SIGHASH_ALL));
                }
                if ((m = tok.match(/^<(\w+)_preimage\((\w+)\)>$/))) {
                    const h = byHash[m[2]];
                    if (!withheldPres.has(h)) used.preimages.push(h);
                    return withheldPres.has(h) ? sha256(Buffer.from('not the preimage')) : preimages[h];
                }
                if ((m = tok.match(/^<(\w+)>$/))) return Buffer.from(m[1], 'hex');
                if (tok === '0') return Buffer.alloc(0);
                if (/^\d+$/.test(tok)) return Buffer.from([Number(tok)]);
                throw new Error('unexpected witness token ' + tok);
            });
            tx.setWitness(0, [...stack, Buffer.from(witnessScript)]);
            const confAt = await chain.confirmedAt(coin.txid);
            const b = await chain.broadcast(tx.toHex());
            Object.assign(r, {
                verdict: b.accepted ? 'accepted' : 'refused',
                txid: b.accepted ? b.txid : undefined, reason: b.reason,
                used, tip, tip_time: await chain.blockTime(tip), coin_confirmed_at: confAt,
                coin_confirmed_time: confAt === null ? null : await chain.blockTime(confAt), coin_txid: coin.txid,
                nsequence: tx.ins[0].sequence, nlocktime: tx.locktime,
                explorer: b.accepted && chain.explorer(b.txid) || undefined
            });
            results.push(r);
            if (b.accepted) coin = { txid: b.txid, vout: 0, value: coin.value - FEE };
        }
        const roles = { ...(spec.keys || {}) };
        for (const [h, v] of Object.entries(spec.hashes || {})) roles[h] = v.name || h;
        return { network: chain.name, policy: spec.policy, miniscript: compiled.miniscript, roles,
                 descriptor, address, keys: keysHex, hashes: hashesHex,
                 funding_txid: fundingTxid, funding_explorer: chain.explorer(fundingTxid) || undefined,
                 date: new Date().toISOString(), attempts: results };
    } finally { await chain.close(); }
}

async function main() {
    const [cmd, arg] = process.argv.slice(2);
    if (cmd === 'compile') {
        process.stdout.write(JSON.stringify(await compile(arg)) + '\n');
    } else if (cmd === 'material') {
        /* the test keys and hashes of a spec's names, without running anything */
        const spec = JSON.parse(fs.readFileSync(arg, 'utf8'));
        const keys = Object.fromEntries(Object.entries(spec.keys || {}).map(([k, role]) => [k, hex(testKey(role).publicKey)]));
        const hashes = Object.fromEntries(Object.entries(spec.hashes || {}).map(([h, { kind, name }]) =>
            [h, hex(hashOf(kind, testPreimage(name || h)))]));
        process.stdout.write(JSON.stringify({ keys, hashes }) + '\n');
    } else if (cmd === 'run') {
        const spec = JSON.parse(fs.readFileSync(arg, 'utf8'));
        process.stdout.write(JSON.stringify(await run(spec), null, 1) + '\n');
    } else {
        process.stderr.write('usage: ms_chain.cjs compile <policy> | material <spec.json> | run <spec.json>\n');
        process.exit(2);
    }
}
main().catch((e) => { process.stderr.write(String(e && e.stack || e) + '\n'); process.exit(1); });
