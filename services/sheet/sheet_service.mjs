// A workbook as an LE service: the `sheet:` address of le_services.pl.
//
//   the knowledge base k includes these services:
//       child support at sheet:ok_child_support.xlsm#support as a calculator.
//   the templates are:
//       the support of *a first income* and *a second income* is *an amount*; via service child support.
//
// The binding between the template and the cells is a SheetPort manifest
// (Formualizer's description of a sheet's typed inputs and outputs) beside
// the workbook: <workbook without extension>.sheetport.yaml. The template's
// known arguments fill the manifest's `in` ports in the order the manifest
// lists them; the answer is the `out` port the address names after `#`, or
// the manifest's only `out` port. The workbook is evaluated with its clock
// fixed (freezeVolatile), so the same question has the same answer.
//
//   node sheet_service.mjs < request.json > reply.json
//   request: {"workbook": path, "port": name|null, "inputs": [value, ...]}
//   reply:   {"answers": [[value]], "rationale": "..."} | {"error": "..."}
//
// The same answer() runs in a browser, given the workbook's and the
// manifest's bytes.

import fs from 'fs';
import path from 'path';
import { SheetPortSession } from 'formualizer';
import { openWorkbook, plainValue } from './sheet_engine.mjs';

export function manifestPath(workbook) {
    return workbook.replace(/\.(xlsx|xlsm)$/i, '') + '.sheetport.yaml';
}

// answer({bytes, manifestYaml, port, inputs, name}) -> {answers, rationale} | {error}
export async function answer({ bytes, manifestYaml, port, inputs, name }) {
    const book = await openWorkbook(bytes);
    const session = SheetPortSession.fromManifestYaml(manifestYaml, book.wb);
    const ports = session.describePorts();
    const list = Array.isArray(ports) ? ports : (ports.ports || []);
    const ins = list.filter(p => (p.dir || p.direction) === 'in');
    const outs = list.filter(p => (p.dir || p.direction) === 'out');
    if (inputs.length !== ins.length)
        return { error: `the template gives ${inputs.length} value(s); the manifest's sheet takes ${ins.length} (${ins.map(p => p.id).join(', ')})` };
    const out = port ? outs.find(p => p.id === port) : (outs.length === 1 ? outs[0] : null);
    if (!out) return { error: port ? `the manifest has no output port ${port}` : `the manifest has ${outs.length} output ports: name one after # in the address` };
    const updates = {};
    ins.forEach((p, i) => { updates[p.id] = inputs[i]; });
    session.writeInputs(updates);
    const res = session.evaluateOnce({ freezeVolatile: true });
    const v = plainValue(res[out.id]);
    if (v && typeof v === 'object' && !Array.isArray(v)) return { error: `the sheet shows ${v.error || JSON.stringify(v)} for ${out.id}` };
    const given = ins.map((p, i) => `${p.id} = ${inputs[i]}`).join(', ');
    return { answers: [[v]], rationale: `${name || 'the workbook'} computed ${out.id} from ${given}` };
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === path.resolve(new URL(import.meta.url).pathname);
if (isMain) {
    let reply;
    try {
        const req = JSON.parse(fs.readFileSync(0, 'utf8'));
        const mf = manifestPath(req.workbook);
        if (!fs.existsSync(req.workbook)) reply = { error: `no workbook at ${req.workbook}` };
        else if (!fs.existsSync(mf)) reply = { error: `no SheetPort manifest at ${mf}` };
        else reply = await answer({ bytes: fs.readFileSync(req.workbook), manifestYaml: fs.readFileSync(mf, 'utf8'),
                                    port: req.port || null, inputs: req.inputs || [], name: path.basename(req.workbook) });
    } catch (e) {
        const d = e && (e.details || e.issues);
        reply = { error: String(e && e.message || e) + (Array.isArray(d) ? ': ' + d.map(x => `${x.path}: ${x.message}`).join('; ') : '') };
    }
    process.stdout.write(JSON.stringify(reply));
}
