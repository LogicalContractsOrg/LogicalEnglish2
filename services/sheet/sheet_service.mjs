// A workbook as an LE service: the `sheet:` address of le_services.pl.
//
//   the knowledge base k includes these services:
//       child support at sheet:ok_child_support.xlsm as a calculator.
//   the templates are:
//       the support of *a first income* and *a second income* is *an amount*; via service child support.
//   the cells of service child support are:
//       the sheet is "Entry".
//       the support of "C5" and "D5" is "C17".
//
// The program says which cells answer the template (le_sheet_cells.pl): the
// template's known arguments are written into the cells of its first places,
// the workbook is recalculated, and the answer is the cell of its last place.
// `the cell "B30" is "monthly".` gives a cell a value for every question.
//
//   node sheet_service.mjs < request.json > reply.json
//   request: {"workbook": path,
//             "cells": {"sheet": name|null, "inputs": [ref, ...], "output": ref,
//                       "fixed": [[ref, value], ...]},
//             "inputs": [value, ...]}
//   reply:   {"answers": [[value]], "rationale": "..."} | {"error": "..."}
//
// The same answer() runs in a browser, given the workbook's bytes.

import fs from 'fs';
import path from 'path';
import { openWorkbook, evaluate, parseCellRef, excelSerial } from './sheet_engine.mjs';

// A value as a cell holds it: a date LE sends as text ("2026-03-15") is a
// date in the workbook, as Excel reads one typed into a cell.
function cellValue(v) {
    if (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v)) {
        const [y, m, d] = v.split('-').map(Number);
        return excelSerial(new Date(Date.UTC(y, m - 1, d)));
    }
    return v;
}

// answer({bytes, cells, inputs, name}) -> {answers, rationale} | {error}
export async function answer({ bytes, cells, inputs, name }) {
    const refs = cells.inputs || [];
    if (inputs.length !== refs.length)
        return { error: `the template gives ${inputs.length} value(s); the program names ${refs.length} input cell(s) (${refs.join(', ')})` };
    const book = await openWorkbook(bytes);
    const sheets = book.parts.sheets.filter(s => !s.isChart).map(s => s.name);
    const sheet = cells.sheet || sheets[0];
    if (!sheets.includes(sheet)) return { error: `the workbook has no sheet "${sheet}" (it has ${sheets.map(s => `"${s}"`).join(', ')})` };
    const all = [...(cells.fixed || []).map(([r]) => r), ...refs, cells.output];
    for (const r of all) {
        let s;
        try { s = parseCellRef(r, sheet).sheet; } catch (e) { return { error: `"${r}" is not a cell reference` }; }
        if (!sheets.includes(s)) return { error: `the workbook has no sheet "${s}", which "${r}" names` };
    }
    const values = {};
    for (const [r, v] of cells.fixed || []) values[r] = cellValue(v);
    refs.forEach((r, i) => { values[r] = cellValue(inputs[i]); });
    const res = evaluate(book, values, [cells.output], sheet);
    const v = res[cells.output];
    if (v && typeof v === 'object' && !Array.isArray(v)) return { error: `the sheet shows ${v.error || JSON.stringify(v)} in ${cells.output}` };
    const given = refs.map((r, i) => `${r} = ${inputs[i]}`).join(', ');
    return { answers: [[v]], rationale: `${name || 'the workbook'} computed ${cells.output} from ${given}` };
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === path.resolve(new URL(import.meta.url).pathname);
if (isMain) {
    let reply;
    try {
        const req = JSON.parse(fs.readFileSync(0, 'utf8'));
        if (!fs.existsSync(req.workbook)) reply = { error: `no workbook at ${req.workbook}` };
        else if (!req.cells || !req.cells.output) reply = { error: 'the request does not say which cells answer the template' };
        else reply = await answer({ bytes: fs.readFileSync(req.workbook), cells: req.cells,
                                    inputs: req.inputs || [], name: path.basename(req.workbook) });
    } catch (e) {
        reply = { error: String(e && e.message || e) };
    }
    process.stdout.write(JSON.stringify(reply));
}
