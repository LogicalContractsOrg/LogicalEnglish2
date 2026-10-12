import { test, expect } from '@playwright/test';
import { smartCompletions, zoneOf, SmartTemplate } from '../src/le-typeahead';

// Pure-logic tests for Smart editing's typeahead (no browser, no server): what
// it offers for the text before the cursor, and where.

const T: SmartTemplate[] = [
    { label: '*a person* is a parent of *a child*' },
    { label: 'the assets of *a company* are *an amount*' },
    { label: '*a person* is happy' },
    { label: '*a person* is rich' },
    { label: '*V1* is greater than *V2*', system: true },
    { label: '*V1* is *V2*', system: true },
];
const S = ['the knowledge base includes:', 'scenario is:', 'query is:'];
const first = (line: string, zone: any = 'body', explicit = false) => smartCompletions(line, zone, T, S, explicit)[0];

test.describe('le-typeahead', () => {
    test('the word being typed completes a fixed word, and the rest follows with its places', () => {
        const it = first('    and alice is a pa');
        expect(it.label).toBe('*a person* is a parent of *a child*');
        expect(it.snippet).toBe('parent of ${1:a child}');
        expect(it.replaceStart).toBe('    and alice is a '.length);
    });

    test('a sentence after "if" in a rule is matched from the "if"', () => {
        const it = first('    a person is happy if the person is a pa');
        expect(it.snippet).toBe('parent of ${1:a child}');
    });

    test('a template that starts with fixed words', () => {
        const it = first('    the ass');
        expect(it.snippet).toBe('assets of ${1:a company} are ${2:an amount}');
    });

    test('after a space, the rest of every template that fits, the more specific first', () => {
        const items = smartCompletions('    bob is ', 'body', T, S);
        const labels = items.map(i => i.label);
        expect(labels).toContain('*a person* is happy');
        expect(labels).toContain('*a person* is a parent of *a child*');
        expect(labels).not.toContain('*V1* is *V2*');            // a built-in that says no more than "is"
    });

    test('a built-in template once it says more than "is"', () => {
        expect(first('    the person is gre').snippet).toBe('greater than ${1:V2}');
    });

    test('"the" in a rule body offers whole sentences, the first place written as "the <noun>"', () => {
        const items = smartCompletions('    a person is rich if the', 'body', T, S);
        const snippets = items.map(i => i.snippet);
        expect(snippets).toContain('${1:the person} is a parent of ${2:a child}');
        expect(snippets).toContain('${1:the person} is happy');
        expect(snippets).toContain('the assets of ${1:a company} are ${2:an amount}');
        const it = items.find(i => i.snippet === '${1:the person} is happy')!;
        expect(it.replaceStart).toBe('    a person is rich if '.length);
        expect(snippets.some(s => s.includes('V1') || s.includes('V2'))).toBe(false);
    });

    test('"the pe" narrows the sentences to those whose first place is a person', () => {
        const items = smartCompletions('    a person is rich if the pe', 'body', T, S);
        expect(items.length).toBeGreaterThan(0);
        expect(items.every(i => i.snippet.startsWith('${1:the person}'))).toBe(true);
    });

    test('"the person " offers the rest of every template that starts with a place', () => {
        const labels = smartCompletions('    a person is rich if the person ', 'body', T, S).map(i => i.label);
        expect(labels).toContain('*a person* is happy');
        expect(labels).toContain('*a person* is a parent of *a child*');
        expect(labels).not.toContain('*V1* is *V2*');
    });

    test('a complete condition is followed by "and" and "or"', () => {
        const items = smartCompletions('    bob is a parent of carol ', 'body', T, S);
        expect(items.map(i => i.label)).toEqual(['and', 'or']);
    });

    test('nothing is offered while templates are being declared', () => {
        expect(smartCompletions('    *a person* is hap', 'templates', T, S)).toEqual([]);
    });

    test('at the margin, the section headings', () => {
        const it = first('sce', 'top');
        expect(it.label).toBe('scenario is:');
        expect(it.replaceStart).toBe(0);
    });

    test('an empty line offers whole templates only when the list is asked for', () => {
        expect(smartCompletions('    ', 'body', T, S, false)).toEqual([]);
        expect(first('    ', 'body', true).snippet).toMatch(/^\$\{1:a person\} is /);
    });

    test('the zone of a line', () => {
        expect(zoneOf(['the templates are:', '    *a person* is happy.'], '    *a')).toBe('templates');
        expect(zoneOf(['the knowledge base t includes:', '    a person is happy'], '    if')).toBe('body');
        expect(zoneOf(['scenario s is:'], '    alice')).toBe('body');
        expect(zoneOf([], 'sce')).toBe('top');
    });
});
