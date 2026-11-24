#!/usr/bin/env node
/**
 * Test script for L4 WASM integration
 *
 * This tests the WASM bridge outside of the browser to verify
 * the core functionality works correctly.
 *
 * Run with: node scripts/test-wasm-integration.mjs
 */

import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

const __dirname = dirname(fileURLToPath(import.meta.url))
const WASM_PATH = new URL('./oracle/jl4-core.wasm', import.meta.url)
const JS_PATH = new URL('./oracle/jl4-core.mjs', import.meta.url).href


// Test helper
function test(name, fn) {
  return async () => {
    try {
      await fn()
      return true
    } catch (e) {
      console.error(`❌ ${name}`)
      console.error(`   Error: ${e.message}`)
      return false
    }
  }
}

// Load JS FFI module
const jsModule = await import(JS_PATH)
const generateImports = jsModule.default

// Load WASM
const wasmBuffer = readFileSync(WASM_PATH)

const wasmModule = await WebAssembly.compile(wasmBuffer)

// Create exports proxy
const exportsProxy = {}

// Generate JS FFI imports
const jsFFIImports = generateImports(exportsProxy)

// WASI imports
const wasiImports = {
  clock_time_get: (_clockId, _precision, out) => {
    const view = new DataView(exportsProxy.memory.buffer)
    view.setBigUint64(out, BigInt(Date.now()) * BigInt(1_000_000), true)
    return 0
  },
  fd_write: (fd, iovs, iovsLen, nwritten) => {
    if (fd === 1 || fd === 2) {
      const view = new DataView(exportsProxy.memory.buffer)
      let totalWritten = 0
      for (let i = 0; i < iovsLen; i++) {
        // Skip ptr (4 bytes), we only need len to calculate totalWritten
        const len = view.getUint32(iovs + i * 8 + 4, true)
        totalWritten += len
      }
      view.setUint32(nwritten, totalWritten, true)
    }
    return 0
  },
  fd_read: () => 0,
  fd_close: () => 0,
  fd_seek: () => 0,
  fd_fdstat_get: () => 0,
  fd_fdstat_set_flags: () => 0,
  fd_filestat_get: () => 0,
  fd_filestat_set_size: () => 0,
  fd_prestat_get: () => 8,
  fd_prestat_dir_name: () => 8,
  path_create_directory: () => 63,
  path_filestat_get: () => 63,
  path_open: () => 63,
  poll_oneoff: () => 0,
  proc_exit: (code) => {
    console.warn('proc_exit:', code)
  },
  args_sizes_get: (argc, argvBufSize) => {
    const view = new DataView(exportsProxy.memory.buffer)
    view.setUint32(argc, 0, true)
    view.setUint32(argvBufSize, 0, true)
    return 0
  },
  args_get: () => 0,
  environ_sizes_get: (environc, environBufSize) => {
    const view = new DataView(exportsProxy.memory.buffer)
    view.setUint32(environc, 0, true)
    view.setUint32(environBufSize, 0, true)
    return 0
  },
  environ_get: () => 0,
}

// Instantiate
const instance = await WebAssembly.instantiate(wasmModule, {
  wasi_snapshot_preview1: wasiImports,
  ghc_wasm_jsffi: jsFFIImports,
})

// Copy exports to proxy
Object.assign(exportsProxy, instance.exports)

// Initialize RTS
instance.exports._initialize()

const exports = instance.exports

// Run tests

const src = readFileSync(process.argv[2], 'utf8')
const r = await exports.l4_eval(src)
console.log(r)
