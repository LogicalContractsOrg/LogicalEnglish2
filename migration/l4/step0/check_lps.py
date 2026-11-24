#!/usr/bin/env python3
"""Step 0 of the design notes l4.md: runs promissory_note_lps.le under LPS2 once
per scenario of the timeless twin (promissory_note.le), and compares the final
state with that scenario's expected answers (which are L4's). Day d after
4 February 2025 is LPS time d + 1. Usage: check_lps.py [lps2 dir] [LE2 dir]"""
import datetime, os, re, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
HERE = os.path.dirname(os.path.abspath(__file__))
LE2 = sys.argv[2] if len(sys.argv) > 2 else os.path.abspath(os.path.join(HERE, '..', '..', '..'))
LPS2 = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(LE2), 'lps2')
START = datetime.date(2025, 2, 4)
def t(d): return (datetime.date.fromisoformat(d) - START).days + 1
base = open(os.path.join(HERE, 'promissory_note_lps.le')).read()
le = open(os.path.join(HERE, 'promissory_note.le')).read()
ok = bad = 0
for m in re.finditer(r'^scenario (\w+) is:\n((?:    .*\n?)+)', le, re.M):
    name, body = m.group(1), m.group(2)
    events = ['    the note starts from 1 to 2.']
    for a, d in re.findall(r'the borrower pays ([\d.]+) on ([\d-]+)\.', body):
        events.append(f'    the borrower pays {a} from {t(d)} to {t(d)+1}.')
    for d in re.findall(r'the clock reaches ([\d-]+)\.', body):
        events.append(f'    the clock is read from {t(d)} to {t(d)+1}.')
    want = None
    f = re.search(r'fulfilled expects answers \["the note is fulfilled on ([\d-]+)"\]', body)
    p = re.search(r'pending expects answers \["the note is pending with the (.*) on a debt of ([\d.]+) since ([\d-]+)"\]', body)
    if f: want = 'fulfilled'
    elif p:
        kind = {'instalment obligation': 'owes_instalment', 'penalty obligation': 'owes_penalty',
                'obligation to pay all debts': 'owes_all'}[p.group(1)]
        want = f'{kind}({p.group(2)},{t(p.group(3))})'
    with tempfile.NamedTemporaryFile('w', suffix='.le', delete=False) as tmp:
        tmp.write(base + f'\nscenario {name} is:\n' + '\n'.join(events) + '\n')
    out = subprocess.run(['./lps', 'run', tmp.name], cwd=LPS2, capture_output=True, text=True,
                         env=dict(os.environ, LPS_LE2_LIB=LE2)).stdout
    os.unlink(tmp.name)
    last = [l for l in out.splitlines() if l.startswith('fluents/')][-1]
    fl = re.findall(r'(\w+)\(([^)]*)\)|\b(fulfilled)\b', last)
    got = []
    for f_, args, ful in fl:
        if ful: got.append('fulfilled'); continue
        a = args.split(',')
        got.append(f'{f_}({round(float(a[0]), 2):.2f},{a[1]})'.replace('.00,', ','))
    want_n = want and re.sub(r'\((\d+\.\d)(,)', r'(\g<1>0\2', want)
    same = [want_n] == got or [want] == got
    ok += same; bad += not same
    print(('PASS' if same else 'FAIL'), name, 'expected', want, 'got', got)
print(f'{ok} passed, {bad} failed')
sys.exit(1 if bad else 0)
