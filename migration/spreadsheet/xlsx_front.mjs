// Front end of the spreadsheet importer: a workbook as JSON for xlsx_ir.pl.
//
// The workbook is read and evaluated by LE2's sheet engine
// (services/sheet/sheet_engine.mjs: Formualizer in WebAssembly), so the
// importer, its oracle and LE2's `sheet:` services evaluate a sheet with the
// same code, and that code runs in a browser as well as under Node.
//
//   node xlsx_front.mjs read   <LE2 dir> <file.xlsx>          > workbook.json
//   node xlsx_front.mjs stream <LE2 dir> <file.xlsx>          > one JSON line per cell
//   node xlsx_front.mjs eval   <LE2 dir> <file.xlsx> < cases.json > values.json
//   node xlsx_front.mjs survey <LE2 dir> <file.xlsx>          > survey.json
//
// read:   sheets, cells (value, the value Excel saved, formula, its syntax
//         tree, style), defined names, validations, comments, macros, and the
//         number texts rewritten for Formualizer (sheet_engine.excelNumberText).
// eval:   {"outputs": [ref...], "cases": [{"id": .., "inputs": {ref: value}}]}
//         -> [{"id": .., "values": {ref: value}}]; every case starts from
//         the workbook as saved, its inputs set.
// survey: the functions used, and how many formula cells Formualizer
//         recomputes to the value Excel saved (the design notes Excel.md §7.7,
//         phase 0).

import fs from 'fs';
import path from 'path';
import { pathToFileURL } from 'url';

const [mode, le2, file] = process.argv.slice(2);
if (!mode || !le2 || !file) {
    process.stderr.write('usage: node xlsx_front.mjs read|eval|survey <LE2 dir> <file.xlsx>\n');
    process.exit(2);
}
const E = await import(pathToFileURL(path.join(le2, 'services/sheet/sheet_engine.mjs')).href);
const bytes = fs.readFileSync(file);

function functionsOf(ast, acc) {
    if (!ast || typeof ast !== 'object') return acc;
    if (ast.type === 'function') acc[ast.name] = (acc[ast.name] || 0) + 1;
    for (const k of ['args', 'elements']) if (Array.isArray(ast[k])) ast[k].flat().forEach(a => functionsOf(a, acc));
    for (const k of ['left', 'right', 'operand']) if (ast[k]) functionsOf(ast[k], acc);
    return acc;
}

function sameValue(a, b) {
    if (a === null || a === undefined) return b === null || b === '' || b === 0 || b === undefined;
    if (b === null || b === undefined) return a === '' || a === 0;
    if (typeof a === 'number' && typeof b === 'number') return Math.abs(a - b) <= 1e-9 * Math.max(1, Math.abs(a), Math.abs(b));
    if (typeof a === 'object' && a.error && typeof b === 'object' && b.error) return a.error === b.error;
    return a === b;
}

if (mode === 'stream') {
    // As read, but one line of JSON per cell after a first line that holds
    // the rest: a workbook of 50,000 formulas is never one document in memory.
    const book = await E.openWorkbook(bytes);
    const head = { file: path.basename(file), macros: book.parts.macros, names: book.parts.names,
                   normalised: book.normalised, sheets: [] };
    const sheets = book.parts.sheets.filter(s => !s.isChart);
    for (const s of sheets) head.sheets.push({ name: s.name, state: s.state, protected: s.protected,
                                               validations: s.validations, merged: s.merged });
    const out = fs.openSync('/dev/stdout', 'w');
    fs.writeSync(out, JSON.stringify(head) + '\n');
    for (const [i, s] of sheets.entries()) {
        for (const [ref, c] of Object.entries(s.cells)) {
            const { row, col } = E.splitA1(ref);
            const cell = { sheet: i + 1, ref, row, col, type: c.type, value: c.type === 'error' ? { error: c.value } : c.value,
                           locked: c.style.locked, fill: c.style.fill, format: c.style.format };
            if (c.formula !== undefined && c.formula !== null) {
                cell.formula = c.formula;
                try { cell.ast = await E.parseFormula(c.formula); }
                catch (e) { cell.ast = { type: 'error', message: String(e && e.message || e) }; }
            }
            if (s.comments[ref]) cell.comment = s.comments[ref];
            fs.writeSync(out, JSON.stringify(cell) + '\n');
        }
    }
    fs.closeSync(out);
} else if (mode === 'read') {
    const book = await E.openWorkbook(bytes);
    const out = { file: path.basename(file), macros: book.parts.macros, names: book.parts.names,
                  normalised: book.normalised, sheets: [] };
    for (const s of book.parts.sheets) {
        if (s.isChart) continue;
        const cells = [];
        for (const [ref, c] of Object.entries(s.cells)) {
            const { row, col } = E.splitA1(ref);
            const cell = { ref, row, col, type: c.type, value: c.type === 'error' ? { error: c.value } : c.value,
                           locked: c.style.locked, fill: c.style.fill, format: c.style.format };
            if (c.formula !== undefined && c.formula !== null) {
                cell.formula = c.formula;
                try { cell.ast = await E.parseFormula(c.formula); }
                catch (e) { cell.ast = { type: 'error', message: String(e && e.message || e) }; }
            }
            if (s.comments[ref]) cell.comment = s.comments[ref];
            cells.push(cell);
        }
        cells.sort((a, b) => a.row - b.row || a.col - b.col);
        out.sheets.push({ name: s.name, state: s.state, protected: s.protected, validations: s.validations,
                          merged: s.merged, cells });
    }
    process.stdout.write(JSON.stringify(out));
} else if (mode === 'eval') {
    const req = JSON.parse(fs.readFileSync(0, 'utf8'));
    const res = [];
    // The workbook is opened once. Every case sets every input any case
    // sets (an input a case leaves out is emptied), so no value of one case
    // leaks into the next.
    const book = await E.openWorkbook(bytes);
    const all = new Set(req.cases.flatMap(c => Object.keys(c.inputs || {})));
    for (const c of req.cases) {
        const inputs = {};
        for (const k of all) inputs[k] = (c.inputs && k in c.inputs) ? c.inputs[k] : null;
        res.push({ id: c.id, values: E.evaluate(book, inputs, req.outputs) });
    }
    process.stdout.write(JSON.stringify(res));
} else if (mode === 'survey') {
    const t0 = Date.now();
    const book = await E.openWorkbook(bytes);
    const fns = {}; let formulas = 0, same = 0, differ = 0, unparsed = 0, cachedErrors = 0;
    const examples = [], differFns = {};
    for (const s of book.parts.sheets) {
        if (s.isChart) continue;
        for (const [ref, c] of Object.entries(s.cells)) {
            if (c.formula === undefined || c.formula === null) continue;
            formulas++;
            try { c.ast = await E.parseFormula(c.formula); functionsOf(c.ast, fns); } catch { unparsed++; }
        }
    }
    const tRead = Date.now() - t0;
    const refs = [], saved = {};
    for (const s of book.parts.sheets) {
        if (s.isChart) continue;
        for (const [ref, c] of Object.entries(s.cells)) {
            if (c.formula === undefined || c.formula === null) continue;
            const r = `'${s.name.replace(/'/g, "''")}'!${ref}`;
            refs.push(r); saved[r] = { v: c.type === 'error' ? { error: c.value } : c.value, f: c.formula, ast: c.ast };
            if (c.type === 'error') cachedErrors++;
        }
    }
    const got = E.evaluate(book, {}, refs);
    for (const r of refs) {
        if (sameValue(got[r], saved[r].v)) same++;
        else { differ++; functionsOf(saved[r].ast, differFns); if (examples.length < 12) examples.push({ cell: r, formula: saved[r].f.slice(0, 120), saved: saved[r].v, got: got[r] }); }
    }
    process.stdout.write(JSON.stringify({
        file: path.basename(file), sheets: book.parts.sheets.filter(s => !s.isChart).map(s => ({ name: s.name, state: s.state, protected: s.protected })),
        macros: book.parts.macros, names: book.parts.names.length, formulas, unparsed, cachedErrors,
        recomputed_same: same, recomputed_differ: differ, normalised: book.normalised.length,
        functions: Object.fromEntries(Object.entries(fns).sort((a, b) => b[1] - a[1])),
        differ_functions: Object.fromEntries(Object.entries(differFns).sort((a, b) => b[1] - a[1])),
        examples, ms_read: tRead, ms_total: Date.now() - t0 }));
}
