#!/usr/bin/env python3
"""The results table of the Blawx twins (README): per project, from the
built twins and their ledgers."""
import json, os, re, glob
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'examples', 'migration', 'blawx')
rows = []
for d in sorted(glob.glob(os.path.join(root, '*', ''))):
    pid = os.path.basename(os.path.dirname(d))
    le = os.path.join(d, pid + '.le'); lj = os.path.join(d, pid + '.ledger.json')
    if not os.path.exists(le):
        continue
    t = open(le, encoding='utf8').read()
    led = json.load(open(lj, encoding='utf8')) if os.path.exists(lj) else {}
    rules = len(re.findall(r'^rule section_\S+ with provenance', t, re.M)) - len(re.findall(r'^rule section_\S+_conclusion ', t, re.M))
    tests = len(re.findall(r'^scenario (?!case_)\S+ is', t, re.M))
    cases = len(re.findall(r'^scenario case_\S+ is', t, re.M))
    exps = len(re.findall(r'^\s+\S+ expects answers', t, re.M))
    pend = len(re.findall(r'^\s+% \S+ expects answers', t, re.M))
    c = led.get('counts', {})
    fid = led.get('fidelity', {})
    rows.append((pid, rules, tests, cases, exps, pend, fid.get('passed', '?'), fid.get('failed', '?'),
                 c.get('encoded', '?'), c.get('approximated', '?'), c.get('residue', '?')))
print('| Project | Rules | Blawx tests | Generated cases | Expectations | Pending | Pass / fail | Ledger (enc/approx/residue) |')
print('|---|---|---|---|---|---|---|---|')
tot = [0] * 8
for r in rows:
    print('| `%s` | %s | %s | %s | %s | %s | %s / %s | %s/%s/%s |' % r)
    for i, v in enumerate(r[1:9]):
        if isinstance(v, int): tot[i] += v
print('| **total** | %d | %d | %d | %d | %d | %d / %d | |' % tuple(tot[:7]))
