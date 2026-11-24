// The oracle checked by RUML's own evaluation tests (both modes): node oracle_check.mjs
// Writes runs/oracle-check.txt and prints the total.
import fs from 'fs'; import path from 'path'; import * as yaml from 'js-yaml'; import jsonata from 'jsonata';
import { evaluate } from './ruml_oracle.mjs';
const here = new URL('.', import.meta.url).pathname;
const root = here + '.cache/ruml/tests';
let pass = 0, total = 0; const lines = [];
async function walk(d) {
  for (const f of fs.readdirSync(d).sort()) {
    const p = path.join(d, f);
    if (fs.statSync(p).isDirectory()) { await walk(p); continue; }
    if (!f.endsWith('.test.yaml')) continue;
    for (const t of yaml.load(fs.readFileSync(p, 'utf8')).tests) {
      if (t.kind !== 'evaluation') continue;
      total++;
      const doc = JSON.parse(fs.readFileSync(path.join(d, t.ruml), 'utf8'));
      const results = await evaluate(doc, t.inputs || {}, t.run.mode);
      const res = { evaluation: { mode: t.run.mode, results } };
      const bad = [];
      for (const a of t.assertions) {
        const got = await jsonata(a.query).evaluate(res);
        if (JSON.stringify(got) !== JSON.stringify(a.expectedValue)) bad.push(`${a.query}: ${JSON.stringify(got)} for ${JSON.stringify(a.expectedValue)}`);
      }
      if (!bad.length) pass++;
      lines.push(`${bad.length ? 'FAIL' : 'pass'}  ${t.name}  ${bad.join('; ')}`);
    }
  }
}
await walk(root);
lines.push(`TOTAL ${pass} of ${total}`);
fs.writeFileSync(here + 'runs/oracle-check.txt', lines.join('\n') + '\n');
console.log(`oracle check: ${pass} of ${total}`);
