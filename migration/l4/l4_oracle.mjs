#!/usr/bin/env node
// The L4 oracle: L4's own evaluator (jl4-core.wasm, fetched by
// fetch_oracle.sh) run under Node.js. Step 1 of the design notes l4.md.
//
//   node l4_oracle.mjs eval FILE ...        every directive's result, as JSON
//                                           (one line per file)
//   node l4_oracle.mjs hover FILE L:C ...   the type at each 1-based position
//   node l4_oracle.mjs cache [--force] ID=FILE ...
//                                           eval each FILE into runs/ID.json
//                                           (kept unless --force)
//
// The evaluator reads one file: an IMPORT of a library it ships (prelude,
// daydate, math, …) works; an IMPORT of another file of the corpus does
// not (the WebAssembly build has no store of the project's files).
//
// The function load() below (the WASI stubs and the instantiation) is adapted
// from ts-apps/jl4-web/scripts/test-wasm-integration.mjs of L4
// (github.com/smucclaw/l4-ide at commit 5e082cf), Copyright 2025 Singapore
// Management University, licensed under the Apache License, Version 2.0
// (http://www.apache.org/licenses/LICENSE-2.0); it was shortened, and its
// console messages were removed. The rest of this file is new.
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs'
import { dirname, join } from 'path'
import { fileURLToPath } from 'url'

const HERE = dirname(fileURLToPath(import.meta.url))
const ORACLE = join(HERE, 'oracle')
const BUILD = existsSync(join(ORACLE, 'BUILD')) ? readFileSync(join(ORACLE, 'BUILD'), 'utf8').trim() : 'unknown'

async function load() {
  const generateImports = (await import(join(ORACLE, 'jl4-core.mjs'))).default
  const mod = await WebAssembly.compile(readFileSync(join(ORACLE, 'jl4-core.wasm')))
  const proxy = {}
  const view = () => new DataView(proxy.memory.buffer)
  const wasi = {
    clock_time_get: (_i, _p, out) => { view().setBigUint64(out, BigInt(Date.now()) * 1000000n, true); return 0 },
    fd_write: (fd, iovs, n, nw) => { let t = 0; for (let i = 0; i < n; i++) t += view().getUint32(iovs + i * 8 + 4, true); view().setUint32(nw, t, true); return 0 },
    fd_read: () => 0, fd_close: () => 0, fd_seek: () => 0, fd_fdstat_get: () => 0, fd_fdstat_set_flags: () => 0,
    fd_filestat_get: () => 0, fd_filestat_set_size: () => 0, fd_prestat_get: () => 8, fd_prestat_dir_name: () => 8,
    path_create_directory: () => 63, path_filestat_get: () => 63, path_open: () => 63, poll_oneoff: () => 0,
    proc_exit: () => {},
    args_sizes_get: (a, b) => { view().setUint32(a, 0, true); view().setUint32(b, 0, true); return 0 }, args_get: () => 0,
    environ_sizes_get: (a, b) => { view().setUint32(a, 0, true); view().setUint32(b, 0, true); return 0 }, environ_get: () => 0,
  }
  const inst = await WebAssembly.instantiate(mod, { wasi_snapshot_preview1: wasi, ghc_wasm_jsffi: generateImports(proxy) })
  Object.assign(proxy, inst.exports)
  inst.exports._initialize()
  return inst.exports
}

// Every directive's result, with 1-based lines and columns.
async function evalFile(x, file) {
  const src = readFileSync(file, 'utf8')
  const r = JSON.parse(await x.l4_eval(src))
  const pos = p => ({ line: p.line + 1, col: p.character + 1 })
  return {
    build: BUILD,
    success: !!r.success,
    results: (r.results || []).map(d => ({ start: pos(d.range.start), end: pos(d.range.end), success: d.success, result: d.result ?? null, error: d.error ?? null })),
    diagnostics: (r.diagnostics || []).map(d => ({ start: pos(d.range.start), severity: d.severity, message: d.message })),
  }
}

const [cmd, ...args] = process.argv.slice(2)
const x = await load()
if (cmd === 'eval') {
  for (const f of args) console.log(JSON.stringify(await evalFile(x, f)))
} else if (cmd === 'hover') {
  const src = readFileSync(args[0], 'utf8')
  const out = {}
  for (const lc of args.slice(1)) {
    const [l, c] = lc.split(':').map(Number)
    const h = await x.l4_hover(src, l - 1, c - 1)
    out[lc] = h === 'null' ? null : JSON.parse(h)
  }
  console.log(JSON.stringify(out))
} else if (cmd === 'cache') {
  const force = args[0] === '--force'
  const runs = join(HERE, 'runs'); mkdirSync(runs, { recursive: true })
  for (const a of args.filter(a => a !== '--force')) {
    const i = a.indexOf('='); const id = a.slice(0, i); const file = a.slice(i + 1)
    const out = join(runs, id + '.json')
    if (existsSync(out) && !force) continue
    writeFileSync(out, JSON.stringify(await evalFile(x, file), null, 1) + '\n')
  }
} else {
  console.error('usage: l4_oracle.mjs eval FILE | hover FILE L:C ... | cache [--force] ID=FILE ...'); process.exit(2)
}
