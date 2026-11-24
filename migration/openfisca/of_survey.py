#!/usr/bin/env python3
"""A package surveyed with the reader itself: every variable with a formula
read as of_extract.py reads it, the residue counted by reason, and the
reads of another period counted from the Python.

    of_survey.py <dialect> [--window 2023-01-01,2026-12-31] [--json out.json]
"""
import ast, collections, json, re, signal, sys, time, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import of_extract

def main(argv):
    dialect = argv[0]
    win = ('2023-01-01', '2026-12-31')
    out = None
    if '--window' in argv:
        win = tuple(argv[argv.index('--window') + 1].split(','))
    if '--json' in argv:
        out = argv[argv.index('--json') + 1]
    t0 = time.time()
    system = of_extract.load_system(dialect)
    load = time.time() - t0
    print(f'  loaded in {load:.0f} s: {len(system.variables)} variables', file=sys.stderr, flush=True)
    params = of_extract.Params(system, win)
    stats, reasons, approx = collections.Counter(), collections.Counter(), collections.Counter()
    periods = collections.Counter()
    per_var = {}
    for name, v in sorted(system.variables.items()):
        if not (v.formulas or getattr(v, 'adds', None) or getattr(v, 'subtracts', None)):
            stats['inputs'] += 1
            continue
        stats['computed'] += 1
        src = ''
        for f in (v.formulas or {}).values():
            try:
                src += of_extract.source_of(f)
            except Exception:
                pass
        for pat, key in ((r'period\.last_year', 'last_year'), (r'period\.n_2', 'n_2'), (r'\.offset\(', 'offset'),
                         (r'period\.this_year', 'this_year'), (r'period\.first_month', 'first_month'),
                         (r'\bADD\b', 'options ADD'), (r'\bDIVIDE\b', 'options DIVIDE'), (r'period\.last_month', 'last_month'),
                         (r'period\.start\.offset|period\.start\.period', 'period arithmetic')):
            if re.search(pat, src):
                periods[key] += 1
        if re.search(r'period\.(last_year|n_2|last_month|last_3_months)|\.offset\(|period\.start\.(offset|period)', src):
            stats['reads another period'] += 1
        class Slow(Exception):
            pass
        def alarm(*_):
            raise Slow()
        signal.signal(signal.SIGALRM, alarm)
        signal.alarm(20)
        if stats['computed'] % 100 == 0:
            print(f'  {stats["computed"]} computed variables read', file=sys.stderr, flush=True)
        try:
            rule, info, *_ = of_extract.variable_rule(system, params, name, {})
            signal.alarm(0)
        except Slow:
            reasons['the reader takes more than 20 seconds'] += 1
            stats['residue'] += 1
            per_var[name] = 'slow'
            print(f'  slow: {name}', file=sys.stderr, flush=True)
            continue
        except Exception as e:
            signal.alarm(0)
            reasons[f'reader error: {type(e).__name__}'] += 1
            stats['residue'] += 1
            per_var[name] = 'error'
            continue
        if rule is None:
            stats['inputs'] += 1
            continue
        if 'residue_reason' in rule:
            r = re.sub(r'\b[a-z_0-9]{3,}\b(?=\(\))', 'f', rule['residue_reason'])
            r = re.sub(r'(the name|unknown variable|parameter|the attribute|the call|the role) \S+.*', r'\1 …', r)
            reasons[r] += 1
            stats['residue'] += 1
            per_var[name] = rule['residue_reason']
        else:
            stats['translated'] += 1
            for a in (rule.get('approximated') or '').split('; '):
                if a:
                    approx[re.sub(r'^\S+', '…', a)[:90]] += 1
    folders = collections.Counter()
    for name, v in system.variables.items():
        f = of_extract.file_of(v) or ''
        m = re.search(r'/model/([^/]+)/([^/]+)', f)
        if m and (v.formulas or getattr(v, 'adds', None)):
            folders[f'{m.group(1)}/{m.group(2)}'] += 1
    res = {'dialect': dialect, 'load_seconds': round(load), 'stats': stats, 'residue_reasons': reasons.most_common(),
           'approximations': approx.most_common(15), 'other_periods': periods, 'folders': folders.most_common(40),
           'parameters': sum(1 for _ in system.parameters.get_descendants()) if hasattr(system.parameters, 'get_descendants') else None,
           'per_variable': per_var}
    print(json.dumps({k: v for k, v in res.items() if k != 'per_variable'}, indent=1, default=str, ensure_ascii=False))
    if out:
        json.dump(res, open(out, 'w'), indent=1, default=str, ensure_ascii=False)

if __name__ == '__main__':
    main(sys.argv[1:])
