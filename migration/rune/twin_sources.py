#!/usr/bin/env python3
"""Copy into each Rune twin's sources/ the Rune files it was translated from.

A twin's ledger (<twin>.ledger.md, written by build.pl and cdm_build.pl)
names every definition of the report's closure by its qualified name
(`drr.base.margin.GetMarginValue`, an alias as `.../alias`). The namespace of
each one (`drr.base.margin`) is declared by one or more files of DRR's
sources (`namespace drr.base.margin` on the first line: the -func, -type,
-enum and -rule files of that namespace). Those files are copied to
<twin>/sources/rosetta/, so that "View ▸ The original this was converted
from" (LE2 le_original_text.pl) finds each definition in them.

DRR is ISDA's, under its own licence, and the twins stay in this private
repository for that reason (README.md); so do their sources.

    python3 twin_sources.py              every twin under examples/migration/rune
    python3 twin_sources.py cftc_part45  one twin (a folder name)
"""
import collections, os, re, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
RUNE = os.path.join(HERE, '.cache', 'drr', 'drr', 'rosetta')
TWINS = os.path.normpath(os.path.join(HERE, '..', '..', 'examples', 'migration', 'rune'))
# A twin without a ledger of its own, and the twin whose ledger covers it:
# the hand-made twin of five CFTC Part 45 fields (hand_build.pl).
LEDGER_OF = {'hand': 'cftc_part45'}

def namespaces_of_files():
    by_ns = collections.defaultdict(list)
    for f in sorted(os.listdir(RUNE)):
        if not f.endswith('.rosetta'):
            continue
        with open(os.path.join(RUNE, f), encoding='utf-8') as h:
            for line in h:
                m = re.match(r'\s*namespace\s+([\w.]+)', line)
                if m:
                    if not m.group(1).startswith('drr.lpsplus'):   # our own test files
                        by_ns[m.group(1)].append(f)
                    break
    return by_ns

def ledger_namespaces(ledger):
    nss = set()
    for line in open(ledger, encoding='utf-8'):
        m = re.match(r'\|\s*`([\w.]+)(?:/[\w.]+)?`\s*\|', line)
        if m and '.' in m.group(1):
            nss.add(m.group(1).rsplit('.', 1)[0])
    return nss

def twin_folders(names):
    for d in sorted(os.listdir(TWINS)):
        p = os.path.join(TWINS, d)
        if names and d not in names:
            continue
        led = os.path.join(TWINS, LEDGER_OF.get(d, d))
        if os.path.isdir(p) and any(f.endswith('.ledger.md') for f in os.listdir(led)):
            yield d, p, led

def main(names):
    by_ns = namespaces_of_files()
    for d, p, led in twin_folders(names):
        nss = set()
        for f in os.listdir(led):
            if f.endswith('.ledger.md'):
                nss |= ledger_namespaces(os.path.join(led, f))
        files = sorted({f for ns in nss for f in by_ns.get(ns, [])})
        missing = sorted(ns for ns in nss if ns not in by_ns)
        out = os.path.join(p, 'sources', 'rosetta')
        if os.path.isdir(out):
            shutil.rmtree(out)
        os.makedirs(out)
        for f in files:
            shutil.copy2(os.path.join(RUNE, f), out)
        with open(os.path.join(p, 'sources', 'README.md'), 'w', encoding='utf-8') as h:
            h.write('# The original of this twin\n\n'
                    'The Rune files of the Digital Regulatory Reporting (DRR) model, version 7.14.0,\n'
                    'that declare the namespaces of the definitions this twin was translated from\n'
                    '(its ledger names each definition). Written by\n'
                    '`migration/rune/twin_sources.py`; do not edit. DRR is ISDA\'s, under ISDA\'s\n'
                    'licence: these files stay in this private repository.\n\n'
                    + ''.join('- `rosetta/%s`\n' % f for f in files))
        print('%-28s %3d namespaces, %3d files%s' % (d, len(nss), len(files),
              (', not found: ' + ' '.join(missing)) if missing else ''))

if __name__ == '__main__':
    main(set(sys.argv[1:]))
