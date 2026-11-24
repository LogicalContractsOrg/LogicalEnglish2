#!/usr/bin/env node
// replay_fetch.js — the on-chain half of the replay validation (§6.1).
//
//   node replay_fetch.js [--rpc URL] [--token ADDRESS] [--blocks N] > replay.json
//
// Takes the last N blocks before the chain head, and for the token (default
// USDC) fetches: its Transfer, Mint and Burn logs in the window, in chain
// order; the balance of every account they touch, and the total supply, at
// the block before the window and at the window's last block (eth_call at a
// block tag — recent blocks, so a non-archive node serves them); for each
// minter, isMinter and minterAllowance before the window; and the proxy's
// implementation address. sol_replay.pl turns this into an LPS scenario for
// the FiatToken twin and compares the state it reaches with the chain's.
'use strict';
const { keccak256 } = require('js-sha3');

const args = process.argv.slice(2);
function opt(name, dflt) { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : dflt; }
const RPC = opt('--rpc', 'https://ethereum-rpc.publicnode.com');
const TOKEN = opt('--token', '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48').toLowerCase();
const NBLOCKS = parseInt(opt('--blocks', '4'), 10);

const topic = sig => '0x' + keccak256(sig);
const T_TRANSFER = topic('Transfer(address,address,uint256)');
const T_MINT = topic('Mint(address,address,uint256)');
const T_BURN = topic('Burn(address,uint256)');
const sel = sig => keccak256(sig).slice(0, 8);

let id = 0;
async function rpc(method, params) {
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      const r = await fetch(RPC, { method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ jsonrpc: '2.0', id: ++id, method, params }) });
      const j = await r.json();
      if (j.error) throw new Error(method + ': ' + JSON.stringify(j.error));
      return j.result;
    } catch (e) {
      if (attempt === 4) throw e;
      await new Promise(res => setTimeout(res, 1000 * (attempt + 1)));
    }
  }
}
const hex = n => '0x' + n.toString(16);
const addrTopic = t => '0x' + t.slice(26);
const pad = a => a.replace(/^0x/, '').padStart(64, '0');

async function call(data, block) {
  const r = await rpc('eth_call', [{ to: TOKEN, data }, hex(block)]);
  return BigInt(r === '0x' ? 0 : r);
}

(async () => {
  const head = parseInt(await rpc('eth_blockNumber', []), 16);
  const last = head - 2;                 // settled
  const first = last - NBLOCKS + 1;
  const before = first - 1;
  const logs = await rpc('eth_getLogs', [{ address: TOKEN, fromBlock: hex(first), toBlock: hex(last),
                                           topics: [[T_TRANSFER, T_MINT, T_BURN]] }]);
  logs.sort((a, b) => (parseInt(a.blockNumber, 16) - parseInt(b.blockNumber, 16)) ||
                      (parseInt(a.logIndex, 16) - parseInt(b.logIndex, 16)));
  const events = [];
  const mintsByTx = {};
  for (const l of logs) {
    if (l.topics[0] === T_MINT) (mintsByTx[l.transactionHash] ||= []).push(addrTopic(l.topics[1]));
  }
  const accounts = new Set(), minters = new Set();
  for (const l of logs) {
    if (l.topics[0] !== T_TRANSFER) continue;
    const from = addrTopic(l.topics[1]), to = addrTopic(l.topics[2]);
    const value = BigInt(l.data).toString();
    const ev = { block: parseInt(l.blockNumber, 16), logIndex: parseInt(l.logIndex, 16),
                 tx: l.transactionHash, from, to, value };
    const zero = '0x0000000000000000000000000000000000000000';
    if (from === zero) { ev.kind = 'mint'; ev.minter = (mintsByTx[l.transactionHash] || [null])[0]; if (ev.minter) minters.add(ev.minter); }
    else if (to === zero) { ev.kind = 'burn'; minters.add(from); }
    else ev.kind = 'transfer';
    if (from !== zero) accounts.add(from);
    if (to !== zero) accounts.add(to);
    events.push(ev);
  }
  const balanceOf = sel('balanceOf(address)'), totalSupply = sel('totalSupply()');
  const isMinter = sel('isMinter(address)'), minterAllowance = sel('minterAllowance(address)');
  const pre = { balances: {}, totalSupply: (await call('0x' + totalSupply, before)).toString(), minters: {} };
  const post = { balances: {}, totalSupply: (await call('0x' + totalSupply, last)).toString() };
  const accs = [...accounts];
  for (let i = 0; i < accs.length; i += 20) {
    await Promise.all(accs.slice(i, i + 20).map(async a => {
      pre.balances[a] = (await call('0x' + balanceOf + pad(a), before)).toString();
      post.balances[a] = (await call('0x' + balanceOf + pad(a), last)).toString();
    }));
  }
  for (const m of minters) {
    pre.minters[m] = { isMinter: (await call('0x' + isMinter + pad(m), before)) === 1n,
                       allowance: (await call('0x' + minterAllowance + pad(m), before)).toString() };
  }
  // the implementation behind the (ZeppelinOS-style) proxy USDC uses
  const slot = '0x' + keccak256('org.zeppelinos.proxy.implementation');
  const impl = await rpc('eth_getStorageAt', [TOKEN, slot, hex(last)]);
  process.stdout.write(JSON.stringify({ rpc: RPC, token: TOKEN, implementation: '0x' + impl.slice(26),
    head, window: { first, last, before }, fetched: new Date().toISOString(),
    topics: { transfer: T_TRANSFER, mint: T_MINT, burn: T_BURN }, events, pre, post }, null, 1));
})().catch(e => { console.error(e.message || e); process.exit(1); });
