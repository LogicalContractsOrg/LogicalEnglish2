#!/usr/bin/env python3
"""The results table of README.md, from the built twins' ledgers and the runs.

    python3 results.py [twins dir]   (default: LE2's examples/migration/rulespec)
"""
import glob, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
TD = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'examples', 'migration', 'rulespec')
rows, tot = [], dict(m=0, e=0, a=0, r=0, p=0, f=0, u=0, pend=0, eng=0, engp=0)
for lf in sorted(glob.glob(os.path.join(TD, '*', '*.ledger.json'))):
    d = json.load(open(lf))
    g = os.path.basename(os.path.dirname(lf))
    name = d['meta']['program']
    c, fi = d['counts'], d.get('fidelity') or {}
    mods = len(d['meta'].get('artifacts', []))
    pend = d.get('pending_expectations') or 0
    pend = pend if isinstance(pend, int) else len(pend)
    rid = name
    runf = None
    for rf in glob.glob(os.path.join(HERE, 'runs', '*.json')):
        if os.path.basename(rf)[:-5].replace('-', '_').lower() == name:
            runf = rf
    eng = engp = 0
    if runf:
        cases = json.load(open(runf)).get('cases', [])
        eng, engp = len(cases), sum(1 for x in cases if x.get('status') == 'pass')
    rows.append((g, name, mods, c['encoded'], c['approximated'], c['residue'],
                 fi.get('passed', 0), fi.get('failed', 0), fi.get('errors', 0), pend, engp, eng))
    for k, v in zip('m e a r p f u pend engp eng'.split(), (mods, c['encoded'], c['approximated'], c['residue'],
                                                          fi.get('passed', 0), fi.get('failed', 0), fi.get('errors', 0), pend, engp, eng)):
        tot[k] += v
print('| Group | Twin | Modules | Encoded | Approx. | Residue | Expectations pass | fail | error | Pending | Engine on the test file |')
print('|---|---|---|---|---|---|---|---|---|---|---|')
for r in rows:
    print('| %s | `%s` | %d | %d | %d | %d | %d | %d | %d | %d | %d of %d |' % r)
print('| **all** | %d twins | %d | %d | %d | %d | **%d** | %d | %d | %d | %d of %d |' % (
    len(rows), tot['m'], tot['e'], tot['a'], tot['r'], tot['p'], tot['f'], tot['u'], tot['pend'], tot['engp'], tot['eng']))
