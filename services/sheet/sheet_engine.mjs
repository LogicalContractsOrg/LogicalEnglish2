// The spreadsheet engine of Logical English: read a workbook, evaluate it.
//
// One module, two users:
//   - the `sheet:` services address (le_services.pl, language.md §17.6): a
//     template answered by a workbook, through sheet_service.mjs;
//   - the spreadsheet importer of lpsPlus (migration/spreadsheet), which
//     reads the workbook's structure here and uses the same evaluation as the
//     oracle of its tests: the sheet computes the expected answers.
//
// Everything is JavaScript and WebAssembly (Formualizer, an MIT/Apache-2.0
// Excel formula engine written in Rust; fflate to unzip), so the same code
// runs under Node on a server and in a browser.
//
// What a workbook is, here: the cells of each sheet (value, formula, the
// value Excel saved for it, style), the defined names, the data-validation
// lists, the comments, which sheets are hidden and which are protected, and
// whether the file holds macros. Formualizer evaluates; the XML of the file
// gives what Formualizer does not keep (saved values, styles, validations,
// comments).

import { unzipSync, strFromU8 } from 'fflate';
import { initializeWasm, Workbook, parse, tokenize } from 'formualizer';

let ready = null;
export function init() {
    if (!ready) ready = initializeWasm();
    return ready;
}

// ---------------------------------------------------------------------------
// Addresses
// ---------------------------------------------------------------------------

export function colName(c) {
    let s = '';
    while (c > 0) { const m = (c - 1) % 26; s = String.fromCharCode(65 + m) + s; c = Math.floor((c - 1) / 26); }
    return s;
}
export function colNumber(s) {
    let n = 0;
    for (const ch of s.toUpperCase()) n = n * 26 + (ch.charCodeAt(0) - 64);
    return n;
}
export function splitA1(a1) {
    const m = /^\$?([A-Za-z]+)\$?(\d+)$/.exec(a1);
    if (!m) return null;
    return { row: parseInt(m[2], 10), col: colNumber(m[1]) };
}
export function a1(row, col) { return colName(col) + row; }

// "Sheet!B3", "'My sheet'!B3" or "B3" (on DefaultSheet) -> {sheet, row, col}
export function parseCellRef(ref, defaultSheet) {
    let sheet = defaultSheet, cell = ref;
    const bang = ref.lastIndexOf('!');
    if (bang >= 0) {
        sheet = ref.slice(0, bang);
        cell = ref.slice(bang + 1);
        if (sheet.startsWith("'") && sheet.endsWith("'")) sheet = sheet.slice(1, -1).replace(/''/g, "'");
    }
    const rc = splitA1(cell);
    if (!rc) throw new Error(`not a cell: ${ref}`);
    return { sheet, row: rc.row, col: rc.col };
}

// ---------------------------------------------------------------------------
// Excel's reading of text as a number
// ---------------------------------------------------------------------------

// Excel (in an English locale) reads "$1,000.50", "(12)" or "10%" as numbers
// wherever arithmetic needs one; Formualizer 0.11 reads only plain numbers
// ("12", "0.5", "10%"). A text literal in a formula that Excel would read as a
// number, and Formualizer would not, is therefore rewritten as that number:
// in the workbook the oracle evaluates, and in the rules the importer writes,
// so both read it alike (the importer's ledger says so).
export function excelNumberText(s) {
    if (typeof s !== 'string') return null;
    let t = s.trim();
    if (t === '') return null;
    let neg = false;
    if (/^\(.*\)$/.test(t)) { neg = true; t = t.slice(1, -1).trim(); }
    if (t.startsWith('-')) { neg = !neg; t = t.slice(1).trim(); }
    let pct = false;
    if (t.endsWith('%')) { pct = true; t = t.slice(0, -1).trim(); }
    const hadCurrency = /^[$€£]/.test(t);
    t = t.replace(/^[$€£]\s*/, '');
    if (!/^(\d{1,3}(,\d{3})+|\d+)?(\.\d*)?$/.test(t) || !/\d/.test(t)) return null;
    const hadThousands = t.includes(',');
    let n = parseFloat(t.replace(/,/g, ''));
    if (pct) n = n / 100;
    if (neg) n = -n;
    // Only what Formualizer would not read itself is worth rewriting.
    return (hadCurrency || hadThousands || /^\(.*\)$/.test(s.trim())) ? n : null;
}

// The formula with every such literal replaced by its number, or null when
// there is none.
export function normaliseFormulaText(formula) {
    let changed = false;
    const out = formula.replace(/"((?:[^"]|"")*)"/g, (m, body) => {
        const n = excelNumberText(body.replace(/""/g, '"'));
        if (n === null) return m;
        changed = true;
        return String(n);
    });
    return changed ? out : null;
}

// ---------------------------------------------------------------------------
// A tiny XML reader: enough for the parts of an .xlsx file we need
// ---------------------------------------------------------------------------

function decodeXml(s) {
    // Excel's own escapes of control characters (_x000D_ for a carriage return)
    // are undone, and a line ends with \n alone, as Formualizer reads it.
    return decodeEntities(s).replace(/_x([0-9A-Fa-f]{4})_/g, (m, h) => String.fromCharCode(parseInt(h, 16))).replace(/\r\n?/g, '\n');
}
function decodeEntities(s) {
    return s.replace(/&(lt|gt|amp|quot|apos|#\d+|#x[0-9a-fA-F]+);/g, (m, e) => {
        switch (e) {
            case 'lt': return '<'; case 'gt': return '>'; case 'amp': return '&';
            case 'quot': return '"'; case 'apos': return "'";
            default: return e[1] === 'x' ? String.fromCodePoint(parseInt(e.slice(2), 16))
                                          : String.fromCodePoint(parseInt(e.slice(1), 10));
        }
    });
}
function attrs(tag) {
    const a = {};
    const re = /([\w:]+)\s*=\s*"([^"]*)"/g;
    let m;
    while ((m = re.exec(tag))) a[m[1].replace(/^\w+:/, m[1].startsWith('r:') ? 'r:' : '')] = decodeXml(m[2]);
    return a;
}
// Every element <name ...>...</name> or <name .../>, as {attrs, body}.
function elements(xml, name) {
    const out = [];
    const re = new RegExp(`<(?:\\w+:)?${name}(\\s[^>]*?)?(/>|>([\\s\\S]*?)</(?:\\w+:)?${name}>)`, 'g');
    let m;
    while ((m = re.exec(xml))) out.push({ attrs: attrs(m[1] || ''), body: m[3] || '' });
    return out;
}
function textOf(body) {
    // the text of <t> runs, as in shared strings and comments
    const ts = elements(body, 't');
    if (ts.length === 0) return decodeXml(body.replace(/<[^>]+>/g, ''));
    return ts.map(t => decodeXml(t.body)).join('');
}

function resolvePath(base, target) {
    if (target.startsWith('/')) return target.slice(1);
    const parts = base.split('/'); parts.pop();
    for (const p of target.split('/')) {
        if (p === '..') parts.pop(); else if (p !== '.') parts.push(p);
    }
    return parts.join('/');
}
function relsOf(files, part) {
    const i = part.lastIndexOf('/');
    const relsPath = `${part.slice(0, i)}/_rels/${part.slice(i + 1)}.rels`;
    const rels = {};
    if (!files[relsPath]) return rels;
    for (const r of elements(strFromU8(files[relsPath]), 'Relationship'))
        rels[r.attrs.Id] = { type: r.attrs.Type, target: resolvePath(part, r.attrs.Target) };
    return rels;
}

// ---------------------------------------------------------------------------
// Reading a workbook
// ---------------------------------------------------------------------------

// readWorkbookParts(bytes) -> the structure the XML holds (no evaluation).
export function readWorkbookParts(bytes) {
    const files = unzipSync(bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes));
    const str = p => (files[p] ? strFromU8(files[p]) : '');
    const wbXml = str('xl/workbook.xml');
    if (!wbXml) throw new Error('not an Excel workbook (.xlsx/.xlsm): no xl/workbook.xml');
    const wbRels = relsOf(files, 'xl/workbook.xml');

    const shared = elements(str('xl/sharedStrings.xml'), 'si').map(si => textOf(si.body));

    // styles: per cell style index, whether the cell is locked, its fill and format
    const stylesXml = str('xl/styles.xml');
    const numFmts = {};
    for (const nf of elements(stylesXml, 'numFmt')) numFmts[nf.attrs.numFmtId] = nf.attrs.formatCode;
    const fills = elements((elements(stylesXml, 'fills')[0] || { body: '' }).body, 'fill').map(f => {
        const fg = elements(f.body, 'fgColor')[0];
        const pat = elements(f.body, 'patternFill')[0];
        if (!pat || pat.attrs.patternType === 'none' || !fg) return null;
        return fg.attrs.rgb ? fg.attrs.rgb : fg.attrs.theme !== undefined ? `theme${fg.attrs.theme}${fg.attrs.tint ? '/' + fg.attrs.tint : ''}` : fg.attrs.indexed ? `indexed${fg.attrs.indexed}` : null;
    });
    const xfs = elements((elements(stylesXml, 'cellXfs')[0] || { body: '' }).body, 'xf').map(x => {
        const prot = elements(x.body, 'protection')[0];
        const fmtId = x.attrs.numFmtId || '0';
        return {
            locked: !(prot && prot.attrs.locked === '0'),
            fill: fills[parseInt(x.attrs.fillId || '0', 10)] || null,
            format: numFmts[fmtId] || builtinFormat(fmtId),
        };
    });

    const sheets = [];
    for (const s of elements(wbXml, 'sheet')) {
        const rel = wbRels[s.attrs['r:id']];
        const part = rel ? rel.target : null;
        const xml = part ? str(part) : '';
        const sheet = {
            name: s.attrs.name,
            state: s.attrs.state || 'visible',
            protected: /<(?:\w+:)?sheetProtection\b[^>]*\bsheet="(1|true)"/.test(xml),
            cells: {},
            validations: [],
            merged: elements(xml, 'mergeCell').map(m => m.attrs.ref),
            isChart: !part || !part.includes('worksheets/'),
        };
        for (const c of elements(xml, 'c')) {
            const ref = c.attrs.r;
            const t = c.attrs.t || 'n';
            const st = xfs[parseInt(c.attrs.s || '0', 10)] || { locked: true, fill: null, format: 'General' };
            const fEl = elements(c.body, 'f')[0];
            const vEl = elements(c.body, 'v')[0];
            let value = null, type = 'blank';
            if (t === 'inlineStr') { value = textOf(c.body); type = 'text'; }
            else if (vEl && vEl.body !== '') {
                const raw = decodeXml(vEl.body);
                if (t === 's') { value = shared[parseInt(raw, 10)]; type = 'text'; }
                else if (t === 'str') { value = raw; type = 'text'; }
                else if (t === 'b') { value = raw === '1'; type = 'boolean'; }
                else if (t === 'e') { value = raw; type = 'error'; }
                else { value = parseFloat(raw); type = 'number'; }
            }
            const cell = { value, type, style: st };
            if (fEl) { cell.formula = fEl.body ? decodeXml(fEl.body) : null; cell.formulaKind = fEl.attrs.t || 'normal'; cell.sharedIndex = fEl.attrs.si; }
            if (fEl || value !== null || !st.locked || st.fill) sheet.cells[ref] = cell;
        }
        // (Excel 2010's x14:dataValidation keeps its range in <xm:sqref> and
        // its formula in <xm:f>: a list taken from cells of another sheet)
        for (const dv of elements(xml, 'dataValidation')) {
            const f1 = elements(dv.body, 'formula1')[0];
            const sq = dv.attrs.sqref || (elements(dv.body, 'sqref')[0] || {}).body || '';
            sheet.validations.push({
                ranges: decodeXml(sq).split(/\s+/).filter(Boolean),
                type: dv.attrs.type || 'any',
                operator: dv.attrs.operator || null,
                formula1: f1 ? decodeXml(f1.body.replace(/<[^>]+>/g, '')) : null,
                formula2: (elements(dv.body, 'formula2')[0] || {}).body || null,
                prompt: dv.attrs.prompt || null,
            });
        }
        // comments (the legacy kind every Excel writes)
        sheet.comments = {};
        if (part) {
            for (const r of Object.values(relsOf(files, part))) {
                if (/\/comments$/.test(r.type)) {
                    for (const cm of elements(str(r.target), 'comment')) sheet.comments[cm.attrs.ref] = textOf(cm.body).trim();
                }
            }
        }
        sheets.push(sheet);
    }

    const names = elements(wbXml, 'definedName').map(d => ({
        name: d.attrs.name,
        ref: decodeXml(d.body),
        scope: d.attrs.localSheetId !== undefined ? (sheets[parseInt(d.attrs.localSheetId, 10)] || {}).name : null,
        hidden: d.attrs.hidden === '1',
    }));
    const macros = Object.keys(files).some(p => /vbaProject\.bin$/i.test(p));
    return { sheets, names, macros };
}

function builtinFormat(id) {
    return ({ 0: 'General', 1: '0', 2: '0.00', 3: '#,##0', 4: '#,##0.00', 9: '0%', 10: '0.00%',
              14: 'm/d/yyyy', 15: 'd-mmm-yy', 16: 'd-mmm', 17: 'mmm-yy', 22: 'm/d/yyyy h:mm',
              44: '_("$"* #,##0.00_)', 49: '@' })[id] || 'General';
}

// ---------------------------------------------------------------------------
// Opening a workbook for evaluation
// ---------------------------------------------------------------------------

// Shared formulas: Excel writes a group of copied formulas once, on its
// first cell, and each other cell of the group as `<f t="shared" si="n"/>`.
// The copy is the first cell's formula with its relative references moved
// by the copy's offset.
function shiftRef(ref, dr, dc) {
    // one operand: [sheet!]A1, A1:B2, A:A, 1:1 (a name is left alone)
    const bang = ref.lastIndexOf('!');
    const pre = bang >= 0 ? ref.slice(0, bang + 1) : '';
    const body = bang >= 0 ? ref.slice(bang + 1) : ref;
    const parts = body.split(':');
    if (!parts.every(p => /^\$?[A-Za-z]{1,3}\$?\d+$|^\$?[A-Za-z]{1,3}$|^\$?\d+$/.test(p))) return ref;
    return pre + parts.map(p => p.replace(/^(\$?)([A-Za-z]{1,3})?(\$?)(\d+)?$/, (m, ca, c, ra, r) => {
        let out = '';
        if (c) out += ca ? ca + c : colName(colNumber(c) + dc);
        if (r) out += ra ? ra + r : String(parseInt(r, 10) + dr);
        return out;
    })).join(':');
}
async function shiftFormula(formula, dr, dc) {
    if (dr === 0 && dc === 0) return formula;
    const toks = (await tokenize('=' + formula)).tokens;
    let out = '', at = 1;
    for (const t of toks) {
        out += ('=' + formula).slice(at, t.pos);
        out += (t.tokenType === 'Operand' && t.subtype === 'Range') ? shiftRef(t.value, dr, dc) : ('=' + formula).slice(t.pos, t.end);
        at = t.end;
    }
    return out + ('=' + formula).slice(at);
}
async function expandSharedFormulas(sheet) {
    const masters = {};
    for (const [ref, c] of Object.entries(sheet.cells))
        if (c.formulaKind === 'shared' && c.formula) masters[c.sharedIndex] = { ref, formula: c.formula };
    for (const [ref, c] of Object.entries(sheet.cells)) {
        if (c.formulaKind !== 'shared' || c.formula || !masters[c.sharedIndex]) continue;
        const m = masters[c.sharedIndex], a = splitA1(m.ref), b = splitA1(ref);
        c.formula = await shiftFormula(m.formula, b.row - a.row, b.col - a.col);
    }
}

// openWorkbook(bytes) -> {wb, parts, normalised: [{sheet, cell, from, to}]}
// The formulas are those of the file (each copy of a shared formula
// written out), with the number texts rewritten (excelNumberText), in the
// importer's view and in the workbook Formualizer evaluates.
export async function openWorkbook(bytes) {
    await init();
    const parts = readWorkbookParts(bytes);
    const wb = Workbook.fromXlsxBytes(bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes));
    const normalised = [];
    for (const s of parts.sheets) {
        if (s.isChart) continue;
        await expandSharedFormulas(s);
        for (const [ref, cell] of Object.entries(s.cells)) {
            if (!cell.formula) continue;
            // the value Excel saved, read as the rewritten formula now gives it
            if (cell.type === 'text') {
                const n = excelNumberText(cell.value);
                if (n !== null) { cell.value = n; cell.type = 'number'; }
            }
            const n = normaliseFormulaText(cell.formula);
            if (n !== null) {
                const { row, col } = splitA1(ref);
                normalised.push({ sheet: s.name, cell: ref, from: cell.formula, to: n });
                cell.formula = n;
                wb.sheet(s.name).setFormula(row, col, '=' + n);
            }
        }
    }
    return { wb, parts, normalised };
}

// A value as the importer and the services see it: a number, a string, a
// boolean, null for an empty cell, or {error: '#N/A'}.
export function plainValue(v) {
    if (v === undefined || v === null) return null;
    if (typeof v === 'number' || typeof v === 'boolean') return v;
    if (typeof v === 'string') return /^#(N\/A|REF!|VALUE!|DIV\/0!|NAME\?|NUM!|NULL!|SPILL!|CALC!|GETTING_DATA)$/.test(v) ? { error: v } : v;
    if (typeof v === 'object' && v.kind === 'error') return { error: v.code };
    if (v instanceof Date) return excelSerial(v);
    if (typeof v === 'object' && (v.kind === 'date' || v.kind === 'datetime')) return excelSerial(new Date(v.value));
    if (Array.isArray(v)) return v.map(r => Array.isArray(r) ? r.map(plainValue) : plainValue(r));
    return String(v);
}

// A date as Excel holds it: days since 30 December 1899 (the 1900 date
// system), the time of day as the fraction.
export function excelSerial(d) {
    return (d.getTime() - Date.UTC(1899, 11, 30)) / 86400000;
}

// evaluate(book, inputs, outputs): set each input {ref: value} (null empties
// the cell), recalculate, and read each output ref. The inputs stay set.
export function evaluate(book, inputs, outputs, defaultSheet) {
    for (const [ref, v] of Object.entries(inputs)) {
        const { sheet, row, col } = parseCellRef(ref, defaultSheet);
        book.wb.setValue(sheet, row, col, v === undefined ? null : v);
    }
    const res = {};
    // One formula Formualizer cannot evaluate (a link to another workbook,
    // say) stops evaluateAll for the whole workbook: then each output is
    // evaluated on its own, and only those that need it fail.
    let all = true;
    try { book.wb.evaluateAll(); } catch (e) { all = false; }
    for (const ref of outputs) {
        const { sheet, row, col } = parseCellRef(ref, defaultSheet);
        try { res[ref] = plainValue(all ? book.wb.sheet(sheet).getValue(row, col) : book.wb.evaluateCell(sheet, row, col)); }
        catch (e) { res[ref] = { error: '#ENGINE', message: String(e && e.message || e) }; }
    }
    return res;
}

// The syntax tree of a formula, with defined names resolved: Formualizer's
// WebAssembly parser leaves a name as an error node, with its place in the
// text; we put the name back, as {type: 'name', name}.
export async function parseFormula(formula) {
    await init();
    const ast = await parse('=' + formula);
    const fix = n => {
        if (!n || typeof n !== 'object') return n;
        if (n.type === 'error' && /named ranges are not supported/.test(n.message || '')) {
            const m = /reference '([^']+)'/.exec(n.message);
            return { type: 'name', name: m ? m[1] : formula.slice(n.sourceStart - 1, n.sourceEnd - 1) };
        }
        for (const k of ['args', 'elements']) if (Array.isArray(n[k])) n[k] = n[k].map(e => Array.isArray(e) ? e.map(fix) : fix(e));
        for (const k of ['left', 'right', 'operand']) if (n[k]) n[k] = fix(n[k]);
        for (const k of ['sourceStart', 'sourceEnd', 'sourceTokenType', 'sourceTokenSubtype']) delete n[k];
        return n;
    };
    return fix(ast);
}
