// Step 3's second opinion (the design notes ruml.md §8): the generated cases of
// every twin, evaluated by our oracle and by the unofficial evaluator of
// TechPrototyper/ruml-tooling (MIT licence, fetched by fetch_sources.sh and built
// with `node packages/core/esbuild.mjs`), in both modes. Each disagreement is
// listed for a person to examine against the specification; neither side is
// believed. Writes runs/second-opinion.txt.
//
//   node second_opinion.mjs <cases.json>
//   cases.json: [{"file", "cases": [{"id", "inputs"}]}], written by ruml_cases.pl
import fs from 'fs';
import { createRequire } from 'module';
import { evaluate } from './ruml_oracle.mjs';
const here = new URL('.', import.meta.url).pathname;
const require = createRequire(import.meta.url);
const core = require(here + '.cache/ruml-tooling/packages/core/dist/core.cjs');

const req = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
let agree = 0, total = 0; const lines = [];
for (const { file, cases } of req) {
  const doc = JSON.parse(fs.readFileSync(file, 'utf8'));
  for (const c of cases) {
    for (const mode of ['complete', 'optimized']) {
      total++;
      const ours = await evaluate(doc, c.inputs || {}, mode);
      let theirs = {};
      try {
        const out = await core.evaluateRuml(doc, { mode, datapoints: c.inputs || {}, frozenClock: '2026-11-24T12:00:00Z' });
        theirs = out.result ? out.result.evaluation.results : {};
      } catch (e) { theirs = { error: String(e) }; }
      const diffs = [];
      for (const p of new Set([...Object.keys(ours), ...Object.keys(theirs)])) {
        const a = ours[p]?.status, b = theirs[p]?.status;
        if (a !== b) diffs.push(`${p}: oracle ${a}, second ${b}`);
      }
      if (!diffs.length) agree++;
      else {
        const shown = diffs.filter(d => d.split(':')[0].split('.').length <= 4).slice(0, 6);
        const more = diffs.length - shown.length;
        lines.push(`DIFFERS ${file.split('/').slice(-2).join('/')} ${c.id} ${mode} ${JSON.stringify(c.inputs)}\n    ${shown.join('\n    ')}${more ? `\n    (and ${more} deeper nodes)` : ''}`);
      }
    }
  }
}
lines.push(`TOTAL ${agree} of ${total} evaluations agree`);
fs.writeFileSync(here + 'runs/second-opinion.txt', lines.join('\n') + '\n');
console.log(`second opinion: ${agree} of ${total} evaluations agree`);
