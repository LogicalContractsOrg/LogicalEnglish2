/*  le-typeahead.ts: "Smart editing" (Misc menu), the predictive typeahead.

    With Smart editing off, the editor offers Monaco's own word completion
    and nothing else. With it on, the editor reads what is being typed as the
    start of a sentence of one of the program's templates, and offers the
    rest of that sentence:

        and alice is a pa|       →  parent of ‹a child›
        the ass|                 →  assets of ‹a company› are ‹an amount›

    A template's places (*a child*) become snippet placeholders, so Tab moves
    from one to the next. The words typed before the cursor are matched
    against the template's fixed words in order; a place takes one or more
    words (a name, a number, "the white rabbit"); the word being typed may be
    the start of the next fixed word. Templates are ranked by how many of
    their fixed words the text already has.

    What is offered depends on where the cursor is:
      - on a line at the margin: the section headings (the knowledge base,
        scenario, query…), which the program's language supplies;
      - in a section that declares templates: nothing, since a template is
        being written, not used;
      - anywhere else (rules, scenarios, queries): the rest of a sentence,
        matched from the last `if`, `and`, `or`, `that`, `unless` or comma;
        and, once a sentence is complete, `and` and `or`. Most templates
        start with a place, so the first words of a sentence are read as
        that place too: `the` or `the pe` offers whole sentences
        ("the person is a parent of ‹a child›"), and `the person ` offers the
        rest of every template that starts with a place, those whose place
        is a person first, when no template matches the words more closely.

    Everything here is pure (no Monaco, no server), so it is tested on its
    own: tests/le-typeahead.spec.ts.
*/

export type Zone = 'top' | 'templates' | 'body';

export interface SmartItem {
    label: string;          // what the list shows: the template, with its places
    snippet: string;        // what is inserted, as a Monaco snippet
    filterText: string;     // what Monaco filters on: the text from replaceStart
    replaceStart: number;   // 0-based column on the line where the insertion starts
    detail: string;
    score: number;          // higher first
    kind: 'template' | 'connective' | 'section';
}

export interface SmartTemplate {
    label: string;          // "*a person* is a parent of *a child*"
    system?: boolean;       // a built-in template ("*V1* is greater than *V2*"): ranked lower
}

type Tok = { word: string } | { place: string };

const ARTICLES = new Set(['a', 'an']);
const CONNECTIVE = new Set(['if', 'and', 'or', 'unless', 'then', 'when']);
//  Where a sentence starts inside a line: after one of these words, or a comma.
const BOUNDARY = /(?:^|[\s,])(?:if|and|or|that|unless|then|when)\s+|,\s*/gi;
const DECLARATION_HEADING = /^(?:the\s+)?(?:templates|predicates|fluents|events|actions|prolog events|ontology)\b.*:\s*$|^(?:os|as|los|las|les|i|le)\s+\S+.*:\s*$/i;

//  A template's words and places, in order. A comma is a word of its own.
export function templateTokens(label: string): Tok[] {
    const out: Tok[] = [];
    for (const part of label.split(/(\*[^*]+\*)/)) {
        if (!part) continue;
        if (part.startsWith('*') && part.endsWith('*') && part.length > 2) {
            out.push({ place: part.slice(1, -1).trim() });
        } else {
            for (const w of words(part)) out.push({ word: w });
        }
    }
    return out;
}

function words(text: string): string[] {
    return text.replace(/,/g, ' , ').split(/\s+/).filter(w => w.length > 0);
}

function same(typed: string, fixed: string): boolean {
    const a = typed.toLowerCase(), b = fixed.toLowerCase();
    return a === b || (ARTICLES.has(a) && ARTICLES.has(b));
}

interface End { next: number; fixed: number; }

//  Every way the complete words W can be read as the start of the template:
//  where in the template they end, and how many fixed words they matched.
function ends(T: Tok[], W: string[]): End[] {
    const out: End[] = [];
    const go = (ti: number, wi: number, fixed: number) => {
        if (wi === W.length) { out.push({ next: ti, fixed }); return; }
        if (ti >= T.length) return;
        const t = T[ti];
        if ('word' in t) {
            if (same(W[wi], t.word)) go(ti + 1, wi + 1, fixed + 1);
            return;
        }
        //  A place takes one word or more: every length is tried. It never
        //  takes a connective ("if", "and"…), which starts another sentence.
        for (let k = 1; wi + k <= W.length && !CONNECTIVE.has(W[wi + k - 1].toLowerCase()); k++) go(ti + 1, wi + k, fixed);
    };
    go(0, 0, 0);
    return out;
}

//  A place as a rule refers to it: "a person" → "the person".
function thePlace(place: string): string {
    const w = place.trim().split(/\s+/);
    if (w.length > 1 && (ARTICLES.has(w[0].toLowerCase()) || w[0].toLowerCase() === 'the')) w[0] = 'the';
    return w.join(' ');
}

//  "the person" (or "a person") typed for the place "a person".
function sameNoun(W: string[], place: string): boolean {
    return W.length > 1 && W.slice(1).join(' ').toLowerCase() === thePlace(place).split(' ').slice(1).join(' ').toLowerCase();
}

function escapeSnippet(s: string): string {
    return s.replace(/[\\$}]/g, m => '\\' + m);
}

//  The template from token `from` on, as a snippet; the first token may be
//  replaced by a completed word.
function remainder(T: Tok[], from: number): { snippet: string; plain: string } {
    let n = 1;
    const snip: string[] = [], plain: string[] = [];
    for (let i = from; i < T.length; i++) {
        const t = T[i];
        if ('word' in t) { snip.push(escapeSnippet(t.word)); plain.push(t.word); }
        else { snip.push('${' + (n++) + ':' + escapeSnippet(t.place) + '}'); plain.push(t.place); }
    }
    const join = (xs: string[]) => xs.join(' ').replace(/ ,/g, ',');
    return { snippet: join(snip), plain: join(plain) };
}

//  The zone of the cursor's line, from the lines above it.
export function zoneOf(linesAbove: string[], line: string): Zone {
    if (!/^\s/.test(line)) return 'top';
    for (let i = linesAbove.length - 1; i >= 0; i--) {
        const l = linesAbove[i];
        if (!l.trim() || /^\s/.test(l) || /^\s*%/.test(l)) continue;
        return DECLARATION_HEADING.test(l.trim()) ? 'templates' : 'body';
    }
    return 'body';
}

/**
 * The suggestions for the text of the line before the cursor.
 * @param lineBefore  the line, up to the cursor
 * @param zone        where the line is (zoneOf)
 * @param templates   the program's templates, and the built-in ones
 * @param sections    the section headings, in the program's language
 * @param explicit    the list was asked for (Ctrl+Space), not opened by typing
 */
export function smartCompletions(lineBefore: string, zone: Zone, templates: SmartTemplate[],
                                 sections: string[], explicit = false): SmartItem[] {
    if (zone === 'templates') return [];
    if (zone === 'top') {
        const typed = lineBefore.trimStart();
        const start = lineBefore.length - typed.length;
        return sections
            .filter(s => explicit || (typed.length > 0 && s.toLowerCase().startsWith(typed.toLowerCase())))
            .map((s, i) => ({ label: s, snippet: escapeSnippet(s), filterText: s, replaceStart: start,
                              detail: 'section', score: 100 - i, kind: 'section' as const }));
    }

    //  Where a sentence may start: the beginning of the line's text, and after
    //  each boundary. The last few are tried, the nearest first.
    const indent = lineBefore.length - lineBefore.trimStart().length;
    const starts = [indent];
    BOUNDARY.lastIndex = 0;
    for (let m; (m = BOUNDARY.exec(lineBefore)) !== null; ) {
        if (m.index + m[0].length > indent) starts.push(m.index + m[0].length);
        if (m[0].length === 0) BOUNDARY.lastIndex++;
    }
    const tried = starts.slice(-4).reverse();

    const best = new Map<string, SmartItem>();
    const placeOnly: SmartItem[] = [];
    let complete = false;
    for (const tpl of templates) {
        const T = templateTokens(tpl.label);
        for (const from of tried) {
            const fragment = lineBefore.slice(from);
            const endsInSpace = fragment.length === 0 || /[\s,]$/.test(fragment);
            const all = words(fragment);
            const partial = endsInSpace ? '' : (all.pop() ?? '');
            const W = all;
            //  The first place being typed ("the", "the pe"): the whole
            //  sentence, its first place written as "the <noun>".
            if (partial && 'place' in T[0] && !tpl.system) {
                const first = thePlace(T[0].place);
                const typed = [...W, partial].join(' ').toLowerCase();
                if (first.toLowerCase().startsWith(typed)) {
                    const r = remainder([{ place: first }, ...T.slice(1)], 0);
                    const item: SmartItem = { label: tpl.label, snippet: r.snippet, filterText: r.plain,
                                              replaceStart: from, detail: 'template',
                                              score: W.length > 0 ? 0.75 : 0.25, kind: 'template' };
                    const prev = best.get(tpl.label);
                    if (!prev || item.score > prev.score) best.set(tpl.label, item);
                }
            }
            for (const e of ends(T, W)) {
                let item: SmartItem | null = null;
                if (partial) {
                    const t = T[e.next];
                    if (t && 'word' in t && t.word.toLowerCase().startsWith(partial.toLowerCase())) {
                        const r = remainder(T, e.next);
                        item = { label: tpl.label, snippet: r.snippet, filterText: r.plain,
                                 replaceStart: lineBefore.length - partial.length,
                                 detail: tpl.system ? 'built-in template' : 'template',
                                 score: e.fixed + 1, kind: 'template' };
                    }
                } else if (e.next < T.length && (e.fixed > 0 || (explicit && W.length === 0))) {
                    const r = remainder(T, e.next);
                    const pad = /\S$/.test(lineBefore) ? ' ' : '';
                    item = { label: tpl.label, snippet: pad + r.snippet, filterText: '',
                             replaceStart: lineBefore.length,
                             detail: tpl.system ? 'built-in template' : 'template',
                             score: e.fixed, kind: 'template' };
                } else if (e.next === T.length && e.fixed > 0 && W.length > 0) {
                    complete = true;
                } else if (e.fixed === 0 && W.length > 0 && W.length <= 3 && e.next === 1
                           && T[1] && 'word' in T[1]) {
                    //  The words typed so far are the template's first place
                    //  ("the person ", "alice "): the rest of the sentence, if
                    //  nothing reads them more closely (below).
                    const r = remainder(T, 1);
                    const p = T[0] as { place: string };
                    placeOnly.push({ label: tpl.label, snippet: r.snippet, filterText: '',
                                     replaceStart: lineBefore.length,
                                     detail: tpl.system ? 'built-in template' : 'template',
                                     score: sameNoun(W, p.place) ? 0.5 : 0, kind: 'template' });
                    continue;
                }
                if (!item) continue;
                //  A built-in template counts only when the text has more of it
                //  than one word ("is"), and below the program's own.
                if (tpl.system) { if (item.score < 2) continue; item.score -= 0.5; }
                const prev = best.get(tpl.label);
                if (!prev || item.score > prev.score) best.set(tpl.label, item);
            }
        }
    }
    if (!complete && ![...best.values()].some(i => i.score >= 1)) {
        for (const item of placeOnly) {
            if (item.detail === 'built-in template') continue;
            const prev = best.get(item.label);
            if (!prev || item.score > prev.score) best.set(item.label, item);
        }
    }
    const items = [...best.values()].sort((a, b) => b.score - a.score || a.label.length - b.label.length);
    if (complete && /\s$/.test(lineBefore)) {
        for (const c of ['and', 'or']) {
            items.push({ label: c, snippet: c + ' ', filterText: '', replaceStart: lineBefore.length,
                         detail: 'next condition', score: -1, kind: 'connective' });
        }
    }
    return items;
}
