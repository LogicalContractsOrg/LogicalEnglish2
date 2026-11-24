#!/usr/bin/env python3
"""The results table of README.md, from the twins' ledgers and the oracle's runs.

    python3 results.py
"""
import glob, json, os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '.cache', 'out', 'of')
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', 'examples', 'migration'))
print('| Twin | Package | Variables (translated / residue / facts of the case) | Parameters | Tests: engine reproduces, in the twin\'s reach | Ledger: encoded / approx. / residue | Expectations pass / fail | Cases left out |')
print('|---|---|---|---|---|---|---|---|')
for lf in sorted(glob.glob(os.path.join(ROOT, '*', '*', '*.ledger.json'))):
    if '/openfisca/' not in lf and '/policyengine/' not in lf:
        continue
    d = json.load(open(lf))
    name = d['meta']['program']
    name = name[3:] if name.startswith('of_') else name
    info = json.load(open(os.path.join(OUT, f'{name}.json')))
    run = json.load(open(os.path.join(OUT, f'{name}.run.json')))
    vs = info['variables'].values()
    tr = sum(1 for v in vs if not v.get('input') and not v.get('residue'))
    rs = sum(1 for v in vs if v.get('residue'))
    ins = sum(1 for v in vs if v.get('input'))
    with open(os.path.join(OUT, f'{name}.yaml')) as fh:
        npar = fh.read().count('kind: parameter')
    st = [c['status'] for c in run['cases']]
    c = d['counts']
    fi = d.get('fidelity') or {}
    left = next((e['mapping'].split(' ')[0] for e in d['entries'] if e.get('element') == 'test cases'), '0')
    print(f"| `{name}` | {info['package']} | {tr} / {rs} / {ins} | {npar} | {st.count('pass')} of {len(st)} | "
          f"{c['encoded']} / {c['approximated']} / {c['residue']} | {fi.get('passed', 0)} / {fi.get('failed', 0)} | {left} |")
