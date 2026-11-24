// The oracle of the RUML translator (the design notes ruml.md §8): an evaluator of
// RUML 1.0 written from the specification alone, with the JSONata library that
// the format's own parser (ruml-js) uses. It shares no code with the twins and
// knows nothing of Logical English. Checked by RUML's 103 evaluation tests
// (oracle_check.mjs).
//
// Usage: node ruml_oracle.mjs < request.json
//   request: {"file": "<path of a .ruml>", "cases": [{"id", "inputs": {...}, "leaves": {"<lexId>": "true"|"false"}, "mode": "complete"|"optimized"}],
//             "maxDepth": 500}
//   reply, one JSON line per case: {"id", "results": {"<path>": {"lexId", "status"}}}
//
// What it implements: the eight operators in both modes (§3.6), ruml:query and
// ruml:expression in JSONata, computed data points (§4.7.2), decisionMode
// (§4.3), modular and recursive nodes with the depth limit (§6), the test
// capabilities of appendix A. A leaf with ruml:ai-query, ruml:tree-include or
// no deciding capability is undefined: nothing here can decide it.
import fs from 'fs';
import jsonata from 'jsonata';

const NEG = { NOT_AND: 'AND', NOT_OR: 'OR', NOT_XOR: 'XOR' };
const flip = s => s === 'true' ? 'false' : s === 'false' ? 'true' : s;

async function truth(expr, input, bind) {
  try {
    const r = await jsonata(expr).evaluate(input, bind || {});
    return r === true ? 'true' : r === false ? 'false' : 'undefined';
  } catch (e) { return 'undefined'; }
}

// The input document: the given values, then the computed data points, in as
// many passes as their dependencies need.
async function inputDocument(doc, inputs) {
  const input = { ...inputs };
  const dps = ((doc.capabilities || []).find(c => c.id === 'ruml:datapoints') || {}).payload?.data || {};
  const computed = Object.entries(dps).filter(([, d]) => d.binding?.type === 'computed');
  for (let pass = 0; pass <= computed.length; pass++) {
    for (const [id, d] of computed) {
      try { const v = await jsonata(d.binding.expression).evaluate(input); if (v !== undefined) input[id] = v; } catch (e) { }
    }
  }
  return input;
}

export async function evaluate(doc, inputs, mode = 'complete', maxDepth = 500, leaves = {}) {
  const nodes = doc.rulemap.nodes, results = {};
  const input = await inputDocument(doc, inputs);
  const role = id => {
    const decl = (doc.capabilities || []).find(c => c.id === id);
    if (decl && decl.role) return decl.role;
    return { 'ruml:query': 'decision', 'ruml:ai-query': 'decision', 'ruml:tree-include': 'decision',
             'ruml:expression': 'combiner', 'org.ruml.test/decision': 'decision', 'org.ruml.test/combiner': 'combiner' }[id] || 'other';
  };
  async function decide(n) {
    const ds = [];
    for (const c of n.capabilities || []) {
      if (role(c.id) !== 'decision') continue;
      if (c.id === 'ruml:query') ds.push(() => truth(c.payload.expression, input));
      else if (c.id === 'org.ruml.test/decision') ds.push(async () => c.payload.result);
      else ds.push(async () => 'undefined');      // ai-query, tree-include, an unknown decision
    }
    if (!ds.length) return leaves[n.__lexId] || 'undefined';    // a person's answer (Appendix A's leaf statuses)
    const dm = n.decisionMode || 'fallback';
    if (dm === 'fallback') { for (const d of ds) { const r = await d(); if (r !== 'undefined') return r; } return 'undefined'; }
    const rs = []; for (const d of ds) rs.push(await d());
    const t = rs.filter(r => r === 'true').length, f = rs.filter(r => r === 'false').length;
    if (dm === 'agreement') return t === rs.length ? 'true' : f === rs.length ? 'false' : 'undefined';
    return t > f ? 'true' : f > t ? 'false' : 'undefined';
  }
  async function ev(lexId, path, stack) {
    const n = nodes[lexId];
    const depth = stack.filter(x => x === lexId).length;
    if (depth > maxDepth) { results[path] = { lexId, status: 'undefined' }; return 'undefined'; }
    let status;
    if (!n.children || !n.children.length) { n.__lexId = lexId; status = await decide(n); }
    else {
      const op0 = n.operator, op = NEG[op0] || op0, st = [];
      const seq = mode === 'optimized' && (op === 'AND' || op === 'XOR');
      let stop = null;
      for (let i = 0; i < n.children.length; i++) {
        const c = n.children[i], p = path + '.' + (i + 1);
        if (stop) { results[p] = { lexId: c, status: 'ignored' }; continue; }
        const s = await ev(c, p, [...stack, lexId]);
        st.push({ lexId: c, label: nodes[c].label, status: s });
        if (seq && ((op === 'AND' && s !== 'true') || (op === 'XOR' && s !== 'false'))) stop = p;
      }
      const has = v => st.some(x => x.status === v);
      if (op === 'DELEGATED') {
        if (has('undefined')) status = 'undefined';
        else {
          const c = (n.capabilities || []).find(c => role(c.id) === 'combiner');
          if (!c) status = 'undefined';
          else if (c.id === 'ruml:expression') status = await truth(c.payload.expression, input, { children: st });
          else if (c.id === 'org.ruml.test/combiner') status = (st[c.payload.pickChildResult - 1] || { status: 'undefined' }).status;
          else status = 'undefined';
        }
      } else if (seq) {
        const last = st[st.length - 1].status;
        status = op === 'AND' ? (last === 'true' ? 'true' : last) : (last === 'false' ? 'false' : last);
      } else if (op === 'AND') status = has('false') ? 'false' : has('undefined') ? 'undefined' : 'true';
      else if (op === 'OR' || op === 'XOR') status = has('true') ? 'true' : has('undefined') ? 'undefined' : 'false';
      else status = 'undefined';
      if (NEG[op0]) status = flip(status);
    }
    results[path] = { lexId, status };
    return status;
  }
  await ev('1', '1', []);
  return results;
}

if (process.argv[1] && process.argv[1].endsWith('ruml_oracle.mjs')) {
  const req = JSON.parse(fs.readFileSync(0, 'utf8'));
  const doc = JSON.parse(fs.readFileSync(req.file, 'utf8'));
  for (const c of req.cases) {
    const results = await evaluate(doc, c.inputs || {}, c.mode || 'complete', req.maxDepth || 500, c.leaves || {});
    console.log(JSON.stringify({ id: c.id, results }));
  }
}
