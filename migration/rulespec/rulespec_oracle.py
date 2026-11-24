#!/usr/bin/env python3
"""The oracle of the RuleSpec translator: Axiom's own engine on a module's tests.

    python3 rulespec_oracle.py us:statutes/7/2017/a [more ids...]
    python3 rulespec_oracle.py --all-under us/statutes/7/2014

For each module: compile it with the engine pinned in corpus.pl (built from
source by fetch_oracle.sh into .cache/engine-src/target/release/), run every
case of its companion `.test.yaml` through `run-compiled` in explain mode,
and write runs/<id with / and : as _>.json:

    {"module": id, "engine": sha, "compile": "ok" | error text,
     "cases": [{"name", "period", "status": "pass" | "fail" | "error",
                "outputs": {key: {"expected", "actual"}}, "error"}]}

A case becomes requests the way Axiom's test harness (axiom-encode,
validator_pipeline.py) builds them: scalar inputs on the query entity, a
relation's items as related entities with their own inputs, one query per
output entity, a parameter output read from the compiled artifact at the
period's start. The corpus is the normalised copy prepare_root.py writes
(metadata only; see there). Runs are cached: a module whose run file exists
is not run again unless --force is given.
"""
import calendar, datetime, decimal, json, os, re, subprocess, sys, tempfile, yaml

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get('RULESPEC_ROOT') or os.path.join(HERE, '.cache', 'root', 'rulespec-us')
ENGINE = os.path.join(HERE, '.cache', 'engine-src', 'target', 'release', 'axiom-rules-engine')
RUNS = os.environ.get('RULESPEC_RUNS') or os.path.join(HERE, 'runs')


def engine_sha():
    try:
        return subprocess.run(['git', '-c', 'safe.directory=*', '-C', os.path.join(HERE, '.cache', 'engine-src'),
                               'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
    except OSError:
        return ''


def module_path(mid):
    juris, rest = mid.split(':', 1)
    return os.path.join(ROOT, juris, rest + '.yaml')


def run_file(mid):
    return os.path.join(RUNS, re.sub(r'[/:]', '_', mid) + '.json')


def period_spec(p):
    if isinstance(p, dict):
        return {k: (v.isoformat() if isinstance(v, datetime.date) else v) for k, v in p.items()}
    if isinstance(p, datetime.date):
        d = p.isoformat()
        return {'period_kind': 'custom', 'name': 'day', 'start': d, 'end': d}
    if isinstance(p, str) and re.fullmatch(r'\d{4}-\d{2}', p.strip()):
        y, m = int(p[:4]), int(p[5:7])
        return {'period_kind': 'month', 'start': f'{y:04d}-{m:02d}-01',
                'end': f'{y:04d}-{m:02d}-{calendar.monthrange(y, m)[1]:02d}'}
    raise ValueError(f'unsupported period {p!r}')


def scalar(v):
    if isinstance(v, bool):
        return {'kind': 'bool', 'value': v}
    if isinstance(v, int):
        return {'kind': 'integer', 'value': v}
    if isinstance(v, float):
        return {'kind': 'decimal', 'value': repr(v)}
    if isinstance(v, datetime.date):
        return {'kind': 'date', 'value': v.isoformat()}
    if isinstance(v, str):
        s = v.strip()
        if re.fullmatch(r'\d{4}-\d{2}-\d{2}', s):
            return {'kind': 'date', 'value': s}
        if re.fullmatch(r'-?\d+', s):
            return {'kind': 'integer', 'value': int(s)}
        if re.fullmatch(r'-?(\d+\.\d*|\d*\.\d+)', s):
            return {'kind': 'decimal', 'value': s}
        return {'kind': 'text', 'value': v}
    raise ValueError(f'unsupported value {v!r}')


def local(key):
    """us:statutes/7/2017/a#input.household_size -> household_size."""
    frag = key.split('#', 1)[1] if '#' in key else key
    for p in ('input.', 'relation.'):
        if frag.startswith(p):
            return frag[len(p):]
    return frag


def same(expected, actual):
    """Does the engine's output equal the case's expected value?"""
    if actual is None:
        return False
    if actual.get('kind') == 'judgment':
        e = str(expected).strip().lower().replace('-', '_')
        if isinstance(expected, bool):
            e = 'holds' if expected else 'not_holds'
        return actual.get('outcome') == e
    v = actual.get('value') if actual.get('kind') == 'scalar' else actual
    if not isinstance(v, dict):
        return False
    if v.get('kind') == 'bool':
        if isinstance(expected, str):
            return v.get('value') == (expected.strip().lower() == 'holds')
        return bool(v.get('value')) == bool(expected)
    if v.get('kind') in ('integer', 'decimal'):
        try:
            return decimal.Decimal(str(v.get('value'))) == decimal.Decimal(str(expected))
        except decimal.InvalidOperation:
            return False
    if isinstance(expected, datetime.date):
        expected = expected.isoformat()
    return str(v.get('value')) == str(expected)


def plain(actual):
    """The engine's output as a plain value for the run file."""
    if actual is None:
        return None
    if actual.get('kind') == 'judgment':
        return actual.get('outcome')
    v = actual.get('value') if actual.get('kind') == 'scalar' else actual
    if isinstance(v, dict):
        return v.get('value')
    return v


def parameter_value(param, period, inputs):
    start = period['start']
    best = None
    for v in param.get('versions', []):
        if v['effective_from'] <= start and (not v.get('effective_to') or start <= v['effective_to']):
            if best is None or v['effective_from'] >= best['effective_from']:
                best = v
    if best is None:
        raise ValueError(f"no version of {param['name']} in force on {start}")
    vals = best.get('values', {})
    if param.get('indexed_by'):
        idx = [v for k, v in inputs.items() if local(str(k)) == param['indexed_by']]
        if not idx or str(idx[0]) not in vals:
            raise ValueError(f"{param['name']} is a table and the case gives no row of it")
        return vals[str(idx[0])]
    if '0' in vals:
        return vals['0']
    raise ValueError(f"{param['name']} has no value")


def run_case(artifact_path, program, catalog, case, idx):
    """catalog: the request names of the program's input slots and relations."""
    period = period_spec(case.get('period'))
    interval = {'start': period['start'], 'end': period['end']}
    derived = {d['name']: d for d in program.get('derived', [])}
    params = {p['name']: p for p in program.get('parameters', [])}
    relations = {local(r['name']): r for r in program.get('relations', [])}
    slots = {}
    for k in catalog:
        slots.setdefault(local(k), k)
    outputs = case.get('output') or {}
    res = {}
    groups = {}
    for key in outputs:
        name = local(str(key))
        if name in derived:
            groups.setdefault(derived[name].get('entity') or 'Case', []).append(key)
        elif name in params:
            try:
                res[key] = {'kind': 'scalar', 'value': parameter_value(params[name], period, case.get('input') or {})}
            except ValueError as e:
                res[key] = {'error': str(e)}
        else:
            res[key] = {'error': f'{key} is not an output of the compiled program'}
    errors = []
    for entity, keys in groups.items():
        qid = str(case.get('entity_id') or case.get('id') or f'case-{idx}')
        inputs, rels = [], []
        given = case.get('input') or {}
        exact = {str(k) for k in given if str(k) in catalog}
        for k, v in given.items():
            k = str(k)
            name = local(k)
            if isinstance(v, list):
                rel = relations.get(name, {})
                sl = rel.get('slot_entities') or []
                cur = sl.index(entity) if entity in sl else 1
                other = sl[1 - cur] if len(sl) == 2 and entity in sl else 'Person'
                for i, item in enumerate(v, 1):
                    rid = str(item.get('id') or item.get('entity_id') or f'{qid}-{name}-{i}')
                    tup = [rid, qid] if cur == 1 else [qid, rid]
                    rels.append({'name': k, 'tuple': tup, 'interval': interval})
                    for ck, cv in item.items():
                        if ck in ('id', 'entity_id'):
                            continue
                        ck = str(ck)
                        if ck not in catalog and local(ck) in slots:
                            ck = slots[local(ck)]
                        inputs.append({'name': ck, 'entity': other, 'entity_id': rid,
                                       'interval': interval, 'value': scalar(cv)})
            else:
                if k not in catalog:
                    if name not in slots or slots[name] in exact:
                        continue    # an input of a module this program does not read
                    k = slots[name]  # the harness matches a key to its slot by name
                    exact.add(k)
                inputs.append({'name': k, 'entity': entity, 'entity_id': qid,
                               'interval': interval, 'value': scalar(v)})
        req = {'mode': 'explain', 'dataset': {'inputs': inputs, 'relations': rels},
               'queries': [{'entity_id': qid, 'period': period, 'outputs': [derived[local(str(k))]['id'] for k in keys]}]}
        p = subprocess.run([ENGINE, 'run-compiled', '--artifact', artifact_path],
                           input=json.dumps(req), capture_output=True, text=True, timeout=120)
        if p.returncode != 0:
            errors.append((p.stderr or p.stdout).strip()[:800])
            continue
        resp = json.loads(p.stdout)
        outs = resp['results'][0]['outputs'] if 'results' in resp else {}
        for k in keys:
            res[k] = outs.get(derived[local(str(k))]['id'])
    case_out = {'name': case.get('name', f'case-{idx}'), 'period': period, 'outputs': {}}
    ok = not errors
    for k, exp in outputs.items():
        act = res.get(k)
        if isinstance(act, dict) and 'error' in act:
            errors.append(act['error'])
            ok = False
            continue
        good = same(exp, act)
        ok = ok and good
        case_out['outputs'][str(k)] = {'expected': exp if not isinstance(exp, datetime.date) else exp.isoformat(),
                                       'actual': plain(act), 'agrees': good}
    case_out['status'] = 'error' if errors else ('pass' if ok else 'fail')
    if errors:
        case_out['error'] = ' | '.join(errors)
    return case_out


def run_module(mid, force=False):
    out = run_file(mid)
    if os.path.exists(out) and not force:
        return json.load(open(out))
    path = module_path(mid)
    record = {'module': mid, 'engine': engine_sha(), 'cases': []}
    with tempfile.TemporaryDirectory() as td:
        art = os.path.join(td, 'compiled.json')
        p = subprocess.run([ENGINE, 'compile', '--program', path, '--rulespec-root', ROOT, '--output', art],
                           capture_output=True, text=True, timeout=300)
        if p.returncode != 0:
            record['compile'] = (p.stderr or p.stdout).strip()[:2000]
        else:
            record['compile'] = 'ok'
            compiled = json.load(open(art))
            program = compiled['program']
            catalog = set()
            for slot in compiled['metadata'].get('input_catalog', []):
                catalog.update(slot.get('request_names', []))
            for r in program.get('relations', []):
                catalog.add(r.get('id', r['name']))
            record['lowered'] = {d['name']: d.get('versions') for d in program.get('derived', [])}
            tf = path[:-5] + '.test.yaml'
            cases = yaml.safe_load(open(tf)) if os.path.exists(tf) else []
            for i, case in enumerate(cases or [], 1):
                try:
                    record['cases'].append(run_case(art, program, catalog, case, i))
                except Exception as e:      # a case the harness would refuse too
                    record['cases'].append({'name': case.get('name', f'case-{i}'), 'status': 'error', 'error': str(e)[:800]})
    os.makedirs(RUNS, exist_ok=True)
    with open(out, 'w') as f:
        json.dump(record, f, indent=1, default=str)
    return record


def ids_under(rel):
    base = os.path.join(ROOT, rel)
    juris = rel.split('/', 1)[0]
    if os.path.exists(base + '.yaml'):
        yield f"{juris}:{os.path.relpath(base, os.path.join(ROOT, juris))}"
    for root, _, files in os.walk(base):
        for fn in sorted(files):
            if fn.endswith('.yaml') and not fn.endswith('.test.yaml'):
                p = os.path.relpath(os.path.join(root, fn), os.path.join(ROOT, juris))
                yield f'{juris}:{p[:-5]}'


def main(argv):
    force = '--force' in argv
    argv = [a for a in argv if a != '--force']
    ids = []
    while argv:
        a = argv.pop(0)
        if a == '--all-under':
            ids.extend(ids_under(argv.pop(0)))
        else:
            ids.append(a)
    tot = {}
    for mid in ids:
        r = run_module(mid, force)
        st = [c['status'] for c in r['cases']]
        for s in st:
            tot[s] = tot.get(s, 0) + 1
        print(f"{mid}: compile {'ok' if r.get('compile') == 'ok' else 'FAILED'}; "
              f"{st.count('pass')} pass, {st.count('fail')} fail, {st.count('error')} error")
    print('total', tot)


if __name__ == '__main__':
    main(sys.argv[1:])
