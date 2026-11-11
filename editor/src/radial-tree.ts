// The Radial Tree of a query (radial-tree.html), opened from Misc > Radial
// Tree or the editor's context menu. The query is at the centre; around it,
// ring by ring, the rules that can conclude it ("OR"), the conditions of each
// rule ("AND", "OR", "NOT"), and the facts that give a condition. The server
// builds the tree (operation radialTree, le_graph:radial_tree/4); this window
// lays it out and draws it in SVG.
//
// Over the tree, the test results of the program's scenarios: each condition
// says in how many scenarios it holds, and a click on a scenario in the Tests
// panel shows which conditions hold in that scenario.
//
// The window talks to the editor over the same le-graph-sync BroadcastChannel
// as the Source Graph (graph-client.ts): state, theme, caret focus, and the
// selection of a node's text in the editor.
import { t, applyI18nDom, installLeApiLang } from './i18n';

interface TreeNode {
    id: string;
    kind: 'query' | 'rule' | 'condition' | 'group' | 'facts' | 'given' | 'builtin' | 'table';
    label: string;
    text?: string;
    tip?: string;
    connector: string | null;
    negated?: boolean;
    recursive?: boolean;
    more?: boolean;
    facts?: number;
    given?: boolean;
    source: { start: number, end: number, [k: string]: any } | null;
    held?: (string | null)[];
    children: TreeNode[];
}

interface ScenarioResult {
    name: string;
    source: { start: number, end: number } | null;
    expected: string[] | null;
    answers: string[];
    result: 'pass' | 'fail' | 'error' | 'none';
    message: string;
}

interface TreeReply {
    query: string;
    text: string;
    source: { start: number, end: number };
    tree: TreeNode;
    scenarios: ScenarioResult[];
    truncated: boolean;
    held_complete: boolean;
}

// A node as laid out: its place, and what the drawing needs.
interface Placed {
    node: TreeNode;
    parent: Placed | null;
    depth: number;
    angle: number;
    x: number;
    y: number;
    leaf: boolean;
}

const SVG_NS = 'http://www.w3.org/2000/svg';
const svg = document.getElementById('tree-svg') as unknown as SVGSVGElement;
const container = document.getElementById('tree-container')!;
const statusEl = document.getElementById('tree-status')!;
const tooltip = document.getElementById('tooltip')!;
const titleEl = document.getElementById('title')!;
const depthSelect = document.getElementById('depth-select') as HTMLSelectElement;
const chkHeld = document.getElementById('chk-held') as HTMLInputElement;
const chkData = document.getElementById('chk-data') as HTMLInputElement;
const chkTests = document.getElementById('chk-tests') as HTMLInputElement;
const testsPanel = document.getElementById('tests-panel')!;
const testsSummary = document.getElementById('tests-summary')!;
const testsBody = document.querySelector('#tests-table tbody') as HTMLTableSectionElement;

const graphChannel = new BroadcastChannel('le-graph-sync');
const params = new URLSearchParams(window.location.search);
const queryName = params.get('query') || '';

let sessionModule: string | null = null;
let reply: TreeReply | null = null;
// The scenario whose results colour the tree (its index), or -1 for none.
let selectedScenario = -1;
// Nodes the user folded (a double click): their children do not show.
const collapsed = new Set<string>();
let placedNodes: Placed[] = [];
let focusedId: string | null = null;

// The radius of the root circle; the smallest radius of the first ring, the
// smallest distance between two rings, and the room that a node needs on its
// ring (the rings of a crowded level grow).
const ROOT_RADIUS = 105;
const FIRST_RING = 190;
const RING_GAP = 200;
const NODE_ROOM = 70;
let ringRadii: number[] = [0];
const LABEL_CHARS = 30;
const LABEL_LINES = 3;

// --- Preferences --------------------------------------------------------------
const PREF = 'le-radial-tree';
function restorePreferences() {
    try {
        const p = JSON.parse(localStorage.getItem(PREF) || 'null');
        if (p && typeof p === 'object') {
            if (p.depth && Array.from(depthSelect.options).some(o => o.value === String(p.depth))) depthSelect.value = String(p.depth);
            if (typeof p.held === 'boolean') chkHeld.checked = p.held;
            if (typeof p.data === 'boolean') chkData.checked = p.data;
            if (typeof p.tests === 'boolean') chkTests.checked = p.tests;
        }
    } catch { /* corrupt or unavailable: keep the defaults */ }
    testsPanel.classList.toggle('hidden', !chkTests.checked);
}
function savePreferences() {
    try {
        localStorage.setItem(PREF, JSON.stringify({
            depth: depthSelect.value, held: chkHeld.checked, data: chkData.checked, tests: chkTests.checked,
        }));
    } catch { /* unavailable */ }
}
restorePreferences();

// --- Status messages ----------------------------------------------------------
function showStatus(message: string) {
    statusEl.textContent = message;
    statusEl.style.display = 'flex';
}
function hideStatus() {
    statusEl.style.display = 'none';
}
function requestLoad(expired: boolean) {
    showStatus(expired
        ? t('The server no longer has the program loaded. Loading it again...')
        : t('Loading the program...'));
    graphChannel.postMessage({ type: 'request-load', data: { expired } });
}

function applyTheme(theme: string) {
    document.body.classList.remove('light-theme', 'hc-theme');
    if (theme === 'le-theme-light') document.body.classList.add('light-theme');
    else if (theme === 'hc-black') document.body.classList.add('hc-theme');
}

// --- Getting the tree ---------------------------------------------------------
async function refreshTree() {
    if (!queryName) {
        showStatus(t('No query. Open the Radial Tree from the editor: select a query, then Misc > Radial Tree.'));
        return;
    }
    if (!sessionModule) { requestLoad(false); return; }
    showStatus(t('Building the tree and running the scenarios...'));
    try {
        const response = await fetch('/leapi', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                token: 'myToken123',
                operation: 'radialTree',
                sessionModule,
                query: queryName,
                depth: parseInt(depthSelect.value, 10) || 4,
            })
        });
        const data = await response.json();
        if (data.session_expired) { requestLoad(true); return; }
        if (data.error_code === 'no_query') {
            showStatus(t('The program has no query with this name: ') + queryName);
            return;
        }
        if (data.error || !data.tree) {
            showStatus(t('The server could not build the tree: ') + (data.error || t('unexpected reply')));
            return;
        }
        reply = data as TreeReply;
        if (selectedScenario >= reply.scenarios.length) selectedScenario = -1;
        hideStatus();
        titleEl.textContent = `${t('Radial Tree')}: ${reply.query} — ${reply.text}`;
        titleEl.title = reply.text;
        renderTests();
        render(true);
    } catch (err) {
        console.error('Failed to get the radial tree', err);
        showStatus(t('Could not reach the server to build the tree.'));
    }
}

// --- Layout -------------------------------------------------------------------
// Which children show: all of them, but the fact leaves only with "Facts" on,
// and none under a folded node.
function visibleChildren(n: TreeNode): TreeNode[] {
    if (collapsed.has(n.id)) return [];
    return chkData.checked ? n.children : n.children.filter(c => c.kind !== 'facts' && c.kind !== 'given');
}

function leafCount(n: TreeNode, memo: Map<string, number>): number {
    const cs = visibleChildren(n);
    const v = cs.length === 0 ? 1 : cs.reduce((s, c) => s + leafCount(c, memo), 0);
    memo.set(n.id, v);
    return v;
}

function radiusOf(depth: number): number {
    return ringRadii[depth] ?? ringRadii[ringRadii.length - 1] + RING_GAP;
}

// How much of its parent's slice a node gets: its leaves, damped, so that
// one deep branch does not squeeze its siblings into a corner.
function weightOf(n: TreeNode, memo: Map<string, number>): number {
    return Math.pow(memo.get(n.id) || 1, 0.6);
}

// Each node gets a slice of its parent's slice, in proportion to its weight,
// and sits at the middle of its slice, on the ring of its depth. A ring is
// at least RING_GAP outside the ring inside it, and further out when its
// narrowest slice leaves less than NODE_ROOM between two neighbours.
function layout(root: TreeNode): Placed[] {
    const memo = new Map<string, number>();
    leafCount(root, memo);
    const out: Placed[] = [];
    const slices: number[] = [];      // the narrowest slice at each depth
    const place = (n: TreeNode, parent: Placed | null, depth: number, a0: number, a1: number) => {
        const cs = visibleChildren(n);
        const p: Placed = { node: n, parent, depth, angle: (a0 + a1) / 2, x: 0, y: 0, leaf: cs.length === 0 };
        out.push(p);
        if (depth > 0) slices[depth] = Math.min(slices[depth] ?? Infinity, a1 - a0);
        const total = cs.reduce((sum, c) => sum + weightOf(c, memo), 0) || 1;
        let a = a0;
        for (const c of cs) {
            const share = (a1 - a0) * weightOf(c, memo) / total;
            place(c, p, depth + 1, a, a + share);
            a += share;
        }
    };
    // Start at the top left, as one reads; a single child sits right above.
    const start = -Math.PI / 2 - Math.PI / 4;
    place(root, null, 0, start, start + 2 * Math.PI);
    ringRadii = [0];
    for (let d = 1; d < slices.length; d++) {
        const least = d === 1 ? FIRST_RING : ringRadii[d - 1] + RING_GAP;
        const room = Math.min(NODE_ROOM / Math.max(slices[d], 1e-3), least + 3 * RING_GAP);
        ringRadii.push(Math.max(least, room));
    }
    for (const p of out) {
        const r = radiusOf(p.depth);
        p.x = r * Math.cos(p.angle);
        p.y = r * Math.sin(p.angle);
    }
    return out;
}

// --- Drawing ------------------------------------------------------------------
function el<K extends keyof SVGElementTagNameMap>(tag: K, attrs: { [k: string]: string | number } = {}, parent?: Element): SVGElementTagNameMap[K] {
    const e = document.createElementNS(SVG_NS, tag);
    for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, String(v));
    if (parent) parent.appendChild(e);
    return e;
}

function wrap(text: string, width: number, maxLines: number): string[] {
    const words = text.replace(/\s+/g, ' ').trim().split(' ');
    const lines: string[] = [];
    let line = '';
    for (const w of words) {
        if (line && (line + ' ' + w).length > width) {
            lines.push(line);
            line = w;
            if (lines.length === maxLines) break;
        } else {
            line = line ? line + ' ' + w : w;
        }
    }
    if (lines.length < maxLines && line) lines.push(line);
    const used = lines.join(' ').length;
    if (used < text.replace(/\s+/g, ' ').trim().length) {
        lines[lines.length - 1] = lines[lines.length - 1].replace(/\s*\S{0,3}$/, '') + '…';
    }
    return lines;
}

// The text in bold beside a node. A rule, or a leaf of facts, says the same
// sentence as the condition above it: it shows which rule it is, or where the
// facts are, instead. A group of conditions shows only its badge.
function displayTitle(p: Placed): string {
    const n = p.node;
    const par = p.parent ? p.parent.node : null;
    if (n.kind === 'group' && (n.label === 'and' || n.label === 'or')) return '';
    if (n.kind === 'facts') return n.facts === 1 ? t('1 fact in the program') : `${n.facts} ${t('facts in the program')}`;
    if (n.kind === 'given') return t('given by the scenarios');
    if (n.kind === 'rule' && par && (n.label === par.label || par.kind === 'query')) {
        const rules = visibleChildren(par).filter(c => c.kind === 'rule');
        return rules.length > 1 ? `${t('rule')} ${rules.indexOf(n) + 1} ${t('of')} ${rules.length}` : t('rule');
    }
    return n.label;
}

function statusIn(n: TreeNode): string | null {
    if (selectedScenario < 0 || !n.held) return null;
    return n.held[selectedScenario] ?? null;
}

function heldCount(n: TreeNode): { yes: number, of: number, unknown: number } | null {
    if (!n.held || n.held.length === 0 || n.held.every(h => h === null)) return null;
    const of = n.held.filter(h => h !== null && h !== 'skipped').length;
    return {
        yes: n.held.filter(h => h === 'yes').length,
        unknown: n.held.filter(h => h === 'unknown').length,
        of,
    };
}

function statusClass(s: string | null): string {
    return s === 'yes' ? 'held' : s === 'no' ? 'not-held' : s === 'unknown' ? 'unknown' : '';
}

// The small line above a node's text: how its children combine, NOT, and,
// with a scenario selected, whether the node holds in it.
function badgeParts(n: TreeNode): { text: string, cls: string }[] {
    const parts: { text: string, cls: string }[] = [];
    if (n.negated) parts.push({ text: t('NOT'), cls: 'badge' });
    if (n.connector && visibleChildren(n).length > 1) parts.push({ text: t(n.connector), cls: 'badge' });
    const s = statusIn(n);
    if (s === 'yes') parts.push({ text: t('Yes'), cls: 'status-yes' });
    else if (s === 'no') parts.push({ text: t('No'), cls: 'status-no' });
    else if (s === 'unknown') parts.push({ text: t('Unknown'), cls: 'status-unknown' });
    return parts;
}

// The grey line below a node's text: what kind of thing it is.
function subLine(n: TreeNode): string {
    if (n.recursive) return t('recursive: see above');
    if (n.more) return t('more conditions: double-click, or increase the depth');
    if (collapsed.has(n.id) && n.children.length > 0) return t('folded: double-click to unfold');
    switch (n.kind) {
        case 'rule': return '';
        case 'facts': return '';
        case 'given': return '';
        case 'builtin': return t('calculation or comparison');
        case 'table': return t('decision table');
        case 'condition':
            if (n.children.length === 0 && !n.more) {
                const parts: string[] = [];
                if (n.facts) parts.push(n.facts === 1 ? t('1 fact in the program') : `${n.facts} ${t('facts in the program')}`);
                if (n.given) parts.push(t('given by the scenarios'));
                if (parts.length === 0) parts.push(t('no rule or fact gives it'));
                return parts.join('; ');
            }
            return '';
        default: return '';
    }
}

let viewBox = { x: -500, y: -500, w: 1000, h: 1000 };
function setViewBox() {
    svg.setAttribute('viewBox', `${viewBox.x} ${viewBox.y} ${viewBox.w} ${viewBox.h}`);
}

function render(fit: boolean) {
    if (!reply) return;
    while (svg.firstChild) svg.removeChild(svg.firstChild);
    placedNodes = layout(reply.tree);
    const maxDepth = placedNodes.reduce((m, p) => Math.max(m, p.depth), 0);

    const rings = el('g', {}, svg);
    for (let d = 1; d <= maxDepth; d++) el('circle', { class: 'ring', cx: 0, cy: 0, r: radiusOf(d) }, rings);

    const edges = el('g', {}, svg);
    const nodesG = el('g', {}, svg);
    const bounds = { x0: -ROOT_RADIUS, y0: -ROOT_RADIUS, x1: ROOT_RADIUS, y1: ROOT_RADIUS };
    const grow = (x: number, y: number) => {
        bounds.x0 = Math.min(bounds.x0, x); bounds.x1 = Math.max(bounds.x1, x);
        bounds.y0 = Math.min(bounds.y0, y); bounds.y1 = Math.max(bounds.y1, y);
    };

    for (const p of placedNodes) {
        if (!p.parent) continue;
        const par = p.parent;
        const from = par.depth === 0
            ? { x: ROOT_RADIUS * Math.cos(p.angle), y: ROOT_RADIUS * Math.sin(p.angle) }
            : { x: par.x, y: par.y };
        const held = statusIn(p.node) === 'yes' && (par.depth === 0 || statusIn(par.node) === 'yes');
        const or = par.node.connector === 'OR' && visibleChildren(par.node).length > 1;
        el('line', {
            class: 'edge' + (held ? ' held' : '') + (or ? ' or' : ''),
            x1: from.x, y1: from.y, x2: p.x, y2: p.y,
        }, edges);
    }

    for (const p of placedNodes) {
        if (p.depth === 0) drawRoot(p, nodesG);
        else drawNode(p, nodesG, grow);
    }

    if (fit) {
        const pad = 60;
        viewBox = { x: bounds.x0 - pad, y: bounds.y0 - pad, w: bounds.x1 - bounds.x0 + 2 * pad, h: bounds.y1 - bounds.y0 + 2 * pad };
        fitAspect();
    }
    setViewBox();
}

// Keep the view box in the window's proportions (centred), so that a zoom
// does not stretch the tree.
function fitAspect() {
    const r = svg.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return;
    const aspect = r.width / r.height;
    const cx = viewBox.x + viewBox.w / 2, cy = viewBox.y + viewBox.h / 2;
    if (viewBox.w / viewBox.h < aspect) viewBox.w = viewBox.h * aspect;
    else viewBox.h = viewBox.w / aspect;
    viewBox.x = cx - viewBox.w / 2;
    viewBox.y = cy - viewBox.h / 2;
}

function drawRoot(p: Placed, parent: Element) {
    const n = p.node;
    const g = el('g', { class: 'node-label', 'data-id': n.id }, parent);
    const s = statusIn(n);
    el('circle', { class: 'root-circle ' + statusClass(s), cx: 0, cy: 0, r: ROOT_RADIUS }, g);
    const badges = badgeParts({ ...n, held: undefined });
    let y = -ROOT_RADIUS + 34;
    if (badges.length) {
        const tx = el('text', { x: 0, y, 'text-anchor': 'middle' }, g);
        badges.forEach((b, i) => {
            const ts = el('tspan', { class: b.cls }, tx);
            ts.textContent = (i ? '  ' : '') + b.text;
        });
    }
    y += 26;
    for (const line of wrap(n.label, 16, 2)) {
        const tx = el('text', { class: 'root-title', x: 0, y, 'text-anchor': 'middle' }, g);
        tx.textContent = line;
        y += 25;
    }
    for (const line of wrap(n.text || '', 30, 2)) {
        const tx = el('text', { class: 'root-text', x: 0, y: y - 4, 'text-anchor': 'middle' }, g);
        tx.textContent = line;
        y += 15;
    }
    if (s === 'yes' || s === 'no') {
        const word = s === 'yes' ? t('YES') : t('NO');
        const w = Math.max(56, word.length * 11 + 22);
        el('rect', { class: 'verdict-box ' + s, x: -w / 2, y: y + 2, width: w, height: 28, rx: 4 }, g);
        const tx = el('text', { class: 'verdict-text ' + s, x: 0, y: y + 22, 'text-anchor': 'middle' }, g);
        tx.textContent = word;
    } else if (chkHeld.checked) {
        const hc = heldCount(n);
        if (hc) {
            const tx = el('text', { class: 'held-line', x: 0, y: y + 12, 'text-anchor': 'middle' }, g);
            tx.textContent = `${t('held in')} ${hc.yes} ${t('of')} ${hc.of}`;
        }
    }
    attachNodeEvents(g, n);
}

function drawNode(p: Placed, parent: Element, grow: (x: number, y: number) => void) {
    const n = p.node;
    const s = statusIn(n);
    const hasHidden = (n.more || (collapsed.has(n.id) && n.children.length > 0));
    const dot = el('circle', {
        class: 'node-dot' + (p.leaf && !hasHidden && !n.recursive ? ' leaf' : '') + (hasHidden || n.recursive ? ' more' : '')
            + ' ' + statusClass(s) + (n.id === focusedId ? ' focused' : ''),
        cx: p.x, cy: p.y, r: p.leaf ? 7 : 8, 'data-id': n.id,
    }, parent);
    attachNodeEvents(dot, n);

    // The label sits beyond the dot, along the ray from the centre: to the
    // right of a dot on the right half, to the left on the left half, and
    // centred above or below near the top and the bottom.
    const cos = Math.cos(p.angle), sin = Math.sin(p.angle);
    const lines: { text: string, cls: string, parts?: { text: string, cls: string }[] }[] = [];
    const badges = badgeParts(n);
    if (badges.length) lines.push({ text: '', cls: '', parts: badges });
    const title = displayTitle(p);
    if (title) for (const l of wrap(title, LABEL_CHARS, LABEL_LINES)) lines.push({ text: l, cls: 'title' });
    let sub = subLine(n);
    if (n.kind === 'rule' && title !== n.label) sub = '';
    if (sub) for (const l of wrap(sub, 38, 2)) lines.push({ text: l, cls: 'sub' });
    if (chkHeld.checked && selectedScenario < 0) {
        const hc = heldCount(n);
        if (hc) lines.push({ text: `${t('held in')} ${hc.yes} ${t('of')} ${hc.of}` + (hc.unknown ? ` (${hc.unknown} ${t('unknown')})` : ''), cls: 'held-line' });
    }
    const lineH = (cls: string) => cls === 'title' ? 19 : 16;
    const height = lines.reduce((h, l) => h + lineH(l.cls), 0);
    let anchor: string, x: number, y: number;
    const gap = 16;
    if (!p.leaf && Math.abs(cos) >= 0.35) {
        // an inner node on a side: edges come in and fan out sideways, so
        // the text goes above the dot
        anchor = 'middle';
        x = p.x;
        y = p.y - gap - height + 12;
    } else if (!p.leaf) {
        // an inner node near the top or the bottom: beside the dot
        anchor = 'start';
        x = p.x + gap;
        y = p.y - height / 2 + 12;
    } else if (Math.abs(cos) < 0.35) {
        anchor = 'middle';
        x = p.x;
        y = sin < 0 ? p.y - gap - height + 12 : p.y + gap + 14;
    } else {
        anchor = cos > 0 ? 'start' : 'end';
        x = p.x + (cos > 0 ? gap : -gap);
        y = p.y - height / 2 + 12;
    }
    const g = el('g', { class: 'node-label' + (n.id === focusedId ? ' focused' : ''), 'data-id': n.id }, parent);
    for (const l of lines) {
        const tx = el('text', { x, y, 'text-anchor': anchor }, g);
        if (l.parts) {
            l.parts.forEach((b, i) => {
                const ts = el('tspan', { class: b.cls }, tx);
                ts.textContent = (i ? '  ' : '') + b.text;
            });
        } else {
            tx.setAttribute('class', l.cls);
            tx.textContent = l.text;
        }
        y += lineH(l.cls);
    }
    attachNodeEvents(g, n);
    // An estimate of the label's extent, for Fit View.
    const width = 8.2 * Math.min(LABEL_CHARS + 4, Math.max(title.length, sub.length * 0.8));
    const left = anchor === 'start' ? x : anchor === 'end' ? x - width : x - width / 2;
    grow(left, y - height - 14);
    grow(left + width, y);
    grow(p.x, p.y);
}

// --- Events -------------------------------------------------------------------
function kindName(n: TreeNode): string {
    switch (n.kind) {
        case 'query': return t('QUERY');
        case 'rule': return t('RULE');
        case 'condition': return t('CONDITION');
        case 'group': return t('GROUP OF CONDITIONS');
        case 'facts': return t('FACTS');
        case 'given': return t('GIVEN BY THE SCENARIOS');
        case 'builtin': return t('CALCULATION OR COMPARISON');
        case 'table': return t('DECISION TABLE');
    }
    return '';
}

function tooltipText(n: TreeNode): string {
    let s = `${kindName(n)}${n.negated ? ' (' + t('NOT') + ')' : ''}: ${n.kind === 'query' ? n.label + ' — ' + (n.text || '') : n.label}`;
    if (n.tip && n.tip !== n.label) s += '\n\n' + n.tip;
    if (reply && n.held && n.held.some(h => h !== null)) {
        s += '\n';
        reply.scenarios.forEach((sc, i) => {
            const h = n.held![i];
            if (h) s += `\n${sc.name}: ${h === 'yes' ? t('Yes') : h === 'no' ? t('No') : h === 'unknown' ? t('Unknown') : t('not checked (time limit)')}`;
        });
    }
    if (n.source) s += '\n\n' + t('Click: show it in the editor. Double-click: fold or unfold.');
    else s += '\n\n' + t('Double-click: fold or unfold.');
    return s;
}

let clickTimer: number | undefined;
function attachNodeEvents(target: Element, n: TreeNode) {
    target.addEventListener('mouseenter', () => {
        tooltip.textContent = tooltipText(n);
        tooltip.style.display = 'block';
    });
    target.addEventListener('mousemove', (e: Event) => {
        const me = e as MouseEvent;
        const x = Math.min(me.clientX + 15, window.innerWidth - tooltip.offsetWidth - 8);
        const y = Math.min(me.clientY + 15, window.innerHeight - tooltip.offsetHeight - 8);
        tooltip.style.left = `${x}px`;
        tooltip.style.top = `${y}px`;
    });
    target.addEventListener('mouseleave', () => { tooltip.style.display = 'none'; });
    target.addEventListener('click', (e: Event) => {
        e.stopPropagation();
        if (dragged) return;
        // A double click must not also select text in the editor twice.
        window.clearTimeout(clickTimer);
        clickTimer = window.setTimeout(() => {
            focusedId = n.id;
            if (n.source && n.source.start !== undefined) {
                graphChannel.postMessage({ type: 'select-range', data: { ...n.source } });
            }
            render(false);
        }, 220);
    });
    target.addEventListener('dblclick', (e: Event) => {
        e.stopPropagation();
        window.clearTimeout(clickTimer);
        if (n.more) {
            // the server stopped here: one level more shows it
            const next = Array.from(depthSelect.options).find(o => parseInt(o.value, 10) > parseInt(depthSelect.value, 10));
            if (next) { depthSelect.value = next.value; savePreferences(); refreshTree(); }
            return;
        }
        if (n.children.length === 0) return;
        if (collapsed.has(n.id)) collapsed.delete(n.id); else collapsed.add(n.id);
        render(false);
    });
}

// Pan with the mouse, zoom with the wheel.
let dragStart: { x: number, y: number, vx: number, vy: number } | null = null;
let dragged = false;
svg.addEventListener('mousedown', (e) => {
    dragStart = { x: e.clientX, y: e.clientY, vx: viewBox.x, vy: viewBox.y };
    dragged = false;
});
window.addEventListener('mousemove', (e) => {
    if (!dragStart) return;
    const r = svg.getBoundingClientRect();
    const k = viewBox.w / r.width;
    const dx = e.clientX - dragStart.x, dy = e.clientY - dragStart.y;
    if (Math.abs(dx) + Math.abs(dy) > 3) { dragged = true; container.classList.add('panning'); }
    viewBox.x = dragStart.vx - dx * k;
    viewBox.y = dragStart.vy - dy * k;
    setViewBox();
});
window.addEventListener('mouseup', () => {
    dragStart = null;
    container.classList.remove('panning');
    window.setTimeout(() => { dragged = false; }, 0);
});
function zoom(factor: number, cx?: number, cy?: number) {
    const px = cx ?? viewBox.x + viewBox.w / 2, py = cy ?? viewBox.y + viewBox.h / 2;
    viewBox.x = px - (px - viewBox.x) * factor;
    viewBox.y = py - (py - viewBox.y) * factor;
    viewBox.w *= factor;
    viewBox.h *= factor;
    setViewBox();
}
svg.addEventListener('wheel', (e) => {
    e.preventDefault();
    const r = svg.getBoundingClientRect();
    const px = viewBox.x + (e.clientX - r.left) / r.width * viewBox.w;
    const py = viewBox.y + (e.clientY - r.top) / r.height * viewBox.h;
    zoom(e.deltaY > 0 ? 1.1 : 1 / 1.1, px, py);
}, { passive: false });

// --- The Tests panel ----------------------------------------------------------
function answersText(a: string[] | null): string {
    if (a === null) return '—';
    if (a.length === 0) return t('none');
    return a.join('; ');
}

function renderTests() {
    if (!reply) return;
    const sc = reply.scenarios;
    testsBody.innerHTML = '';
    const tested = sc.filter(s => s.expected !== null);
    const passed = tested.filter(s => s.result === 'pass').length;
    testsSummary.innerHTML = '';
    if (sc.length === 0) {
        testsSummary.textContent = t('The program has no scenarios.');
        return;
    }
    if (tested.length > 0) {
        const big = document.createElement('span');
        big.className = 'big';
        big.textContent = `${passed}/${tested.length}`;
        testsSummary.appendChild(big);
        testsSummary.appendChild(document.createTextNode(t('tests passed for this query.')));
    } else {
        testsSummary.appendChild(document.createTextNode(t('No scenario expects answers for this query.')));
    }
    const hint = document.createElement('div');
    hint.textContent = `${sc.length} ${t('scenarios. Click a scenario to show which conditions are true in it; click it again to show the counts.')}`;
    testsSummary.appendChild(hint);
    if (!reply.held_complete) {
        const warn = document.createElement('div');
        warn.className = 'result-error';
        warn.textContent = t('The time limit stopped some checks: some counts are incomplete.');
        testsSummary.appendChild(warn);
    }
    if (reply.truncated) {
        const warn = document.createElement('div');
        warn.className = 'result-error';
        warn.textContent = t('The tree is too large: some conditions are not unfolded.');
        testsSummary.appendChild(warn);
    }
    sc.forEach((s, i) => {
        const tr = document.createElement('tr');
        if (i === selectedScenario) tr.className = 'selected';
        const cells = [
            { text: s.name, cls: '' },
            { text: answersText(s.expected), cls: '' },
            // a scenario not run (the time limit): no answers to show
            { text: s.result === 'none' && s.message ? '—' : answersText(s.answers), cls: '' },
            {
                text: s.result === 'pass' ? t('Pass') : s.result === 'fail' ? t('Fail') : s.result === 'error' ? t('Error') : '—',
                cls: 'result-' + s.result,
            },
        ];
        cells.forEach((c, j) => {
            const td = document.createElement('td');
            td.textContent = c.text;
            if (c.cls) td.className = c.cls;
            td.title = (j === 3 || (j === 2 && s.result === 'none')) && s.message ? t(s.message) : c.text;
            tr.appendChild(td);
        });
        tr.addEventListener('click', () => {
            selectedScenario = selectedScenario === i ? -1 : i;
            renderTests();
            render(false);
        });
        tr.addEventListener('dblclick', () => {
            if (s.source) graphChannel.postMessage({ type: 'select-range', data: { ...s.source } });
        });
        tr.title = t('Click: show which conditions are true in this scenario. Double-click: show the scenario in the editor.');
        testsBody.appendChild(tr);
    });
}

// --- The editor's caret -------------------------------------------------------
function focusNodeAtOffset(offset: number) {
    let best: Placed | null = null;
    let bestRange = Infinity;
    for (const p of placedNodes) {
        const s = p.node.source;
        if (s && s.start <= offset && offset <= s.end && s.end - s.start < bestRange) {
            best = p;
            bestRange = s.end - s.start;
        }
    }
    const id = best ? best.node.id : null;
    if (id !== focusedId) {
        focusedId = id;
        render(false);
    }
}

// --- Messages from the editor -------------------------------------------------
let stateReceived = false;
graphChannel.onmessage = (event) => {
    const { type, data } = event.data;
    switch (type) {
        case 'init-state':
            stateReceived = true;
            sessionModule = data.sessionModule;
            applyTheme(data.theme);
            if (data.isLoaded) refreshTree(); else requestLoad(false);
            break;
        case 'load-failed':
            showStatus(t('The program could not be loaded: ') + (data.error || ''));
            break;
        case 'theme-change':
            applyTheme(data.theme);
            break;
        case 'focus-offset':
            focusNodeAtOffset(data.offset);
            break;
        case 'module-loaded':
            sessionModule = data.sessionModule;
            refreshTree();
            break;
    }
};

// --- Controls -----------------------------------------------------------------
document.getElementById('btn-refresh')!.addEventListener('click', () => refreshTree());
document.getElementById('btn-fit')!.addEventListener('click', () => render(true));
document.getElementById('btn-zoom-in')!.addEventListener('click', () => zoom(1 / 1.2));
document.getElementById('btn-zoom-out')!.addEventListener('click', () => zoom(1.2));
depthSelect.addEventListener('change', () => { savePreferences(); collapsed.clear(); refreshTree(); });
chkHeld.addEventListener('change', () => { savePreferences(); render(false); });
chkData.addEventListener('change', () => { savePreferences(); render(true); });
chkTests.addEventListener('change', () => {
    savePreferences();
    testsPanel.classList.toggle('hidden', !chkTests.checked);
    render(true);
});
window.addEventListener('resize', () => { fitAspect(); setViewBox(); });

// Test-only hook (enabled by the same localStorage flag as the Source Graph's).
try {
    if (localStorage.getItem('le_graph_test') === '1') {
        (window as any).__radialTest = {
            reply: () => reply,
            labels: () => placedNodes.map(p => p.node.label),
            selectScenario: (i: number) => { selectedScenario = i; renderTests(); render(false); },
        };
    }
} catch { /* localStorage unavailable */ }

installLeApiLang();
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => applyI18nDom());
} else {
    applyI18nDom();
}

showStatus(t('Waiting for the editor...'));
graphChannel.postMessage({ type: 'request-state' });
setTimeout(() => {
    if (!stateReceived) {
        showStatus(t('No editor answered. Open the Radial Tree from the editor: select a query, then Misc > Radial Tree.'));
    }
}, 4000);
