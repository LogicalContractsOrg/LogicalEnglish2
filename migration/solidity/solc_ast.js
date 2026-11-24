#!/usr/bin/env node
// solc_ast.js — compile Solidity sources with solcjs and print, as JSON, what the
// LE front end (sol_front.pl) reads: every source's compact typed AST, and the
// storage layout of every contract.
//
//   node solc_ast.js File.sol [More.sol ...] > out.json
//
// Imports are resolved against the including file's directory and against
// node_modules (so "@openzeppelin/contracts/..." works after `npm install`).
'use strict';
const fs = require('fs');
const path = require('path');
const solc = require('solc');

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error('usage: node solc_ast.js File.sol [More.sol ...]');
  process.exit(2);
}
const sources = {};
for (const f of files) sources[f] = { content: fs.readFileSync(f, 'utf8') };

const roots = [process.cwd(), __dirname, path.join(__dirname, 'node_modules')];
const imported = {};
function findImports(p) {
  const candidates = [p];
  for (const r of roots) candidates.push(path.join(r, p));
  for (const f of files) candidates.push(path.join(path.dirname(f), p));
  for (const c of candidates) {
    if (fs.existsSync(c) && fs.statSync(c).isFile()) {
      imported[p] = fs.readFileSync(c, 'utf8');
      return { contents: imported[p] };
    }
  }
  return { error: 'File not found: ' + p };
}

const input = {
  language: 'Solidity',
  sources,
  settings: {
    outputSelection: { '*': { '': ['ast'], '*': ['storageLayout', 'abi'] } },
  },
};
const out = JSON.parse(solc.compile(JSON.stringify(input), { import: findImports }));
const errors = (out.errors || []).filter(e => e.severity === 'error');
if (errors.length) {
  for (const e of errors) console.error(e.formattedMessage);
  process.exit(1);
}
// texts: the source of each unit by its index (the third field of every
// AST node's `src`, "start:length:index"), for quoting residue fragments.
const result = { compiler: solc.version(), sources: {}, contracts: {}, texts: {} };
for (const [name, s] of Object.entries(out.sources)) {
  result.sources[name] = s.ast;
  const text = sources[name] ? sources[name].content : imported[name];
  if (text !== undefined) result.texts[String(s.id)] = text;
}
for (const [file, cs] of Object.entries(out.contracts || {}))
  for (const [cname, c] of Object.entries(cs))
    result.contracts[file + ':' + cname] = { storageLayout: c.storageLayout, abi: c.abi };
process.stdout.write(JSON.stringify(result));
