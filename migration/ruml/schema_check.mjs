// The JSON Schema check of RUML files, with the schemas the format publishes
// (gate.pl, step 1; ruml_export.pl, every export). Usage:
//   node schema_check.mjs <kind> <file>...     kind: ruml | ruml-result | ruml-ext
// Prints one JSON line per file: {"file", "valid", "errors": [{"path", "message"}]}
import fs from 'fs';
import Ajv2020 from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';
const here = new URL('.', import.meta.url).pathname;
const kind = process.argv[2];
const schemaFile = here + '.cache/ruml/schemas/' + kind + '.schema.json';
const ajv = new Ajv2020.default({ strict: false, allErrors: true });
addFormats.default(ajv);
const validate = ajv.compile(JSON.parse(fs.readFileSync(schemaFile, 'utf8')));
for (const file of process.argv.slice(3)) {
  let out;
  try {
    const raw = fs.readFileSync(file);
    const text = new TextDecoder('utf-8', { fatal: true }).decode(raw);
    const ok = validate(JSON.parse(text));
    out = { file, valid: ok, errors: ok ? [] : validate.errors.slice(0, 20).map(e => ({ path: e.instancePath, message: e.message })) };
  } catch (e) {
    out = { file, valid: false, errors: [{ path: '', message: String(e.message || e) }] };
  }
  console.log(JSON.stringify(out));
}
