#!/usr/bin/env python3
"""The oracle of the OpenFisca / PolicyEngine translator: the package's own engine.

    of_oracle.py <dialect> <out dir> <programme>...

Runs each test case of <out>/of/<programme>.json (the package's own YAML
tests, as of_extract.py found them) through the package's engine, as
OpenFisca's test runner does (SimulationBuilder.build_from_dict, then
calculate, compared with the expected value within the test's margin), and
writes <out>/of/<programme>.run.json in the shape migration/rulespec's
runs have: {"cases": [{"name", "status", "why"}]}, a case's status `pass`
only when the engine reproduces it and the twin can read it (its period is
the one its outputs are defined for).
"""
import gc, json, os, sys, yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from of_extract import load_system, num, flat_output, PERSON_ENTITIES  # noqa: E402

CORE = {}


def core(dialect):
    """The engine the package runs on: PolicyEngine's fork of OpenFisca's
    core for the PolicyEngine packages, OpenFisca's own otherwise."""
    if not CORE:
        if dialect in ('us', 'uk'):
            from policyengine_core.simulations import SimulationBuilder
            from policyengine_core.tools import assert_near
        else:
            from openfisca_core.simulation_builder import SimulationBuilder
            from openfisca_core.tools import assert_near
        CORE.update(builder=SimulationBuilder, near=assert_near)
        double_precision(dialect)
    return CORE


def double_precision(dialect):
    """The engine's amounts in double precision (it keeps them in single
    precision, where 20,386.028 and 20,386.03 are one number): set before
    the package is loaded, so every variable of a number is created so. A
    test's answers are then known to the cent, and the twin can be told
    whether a figure is a whole number of cents."""
    import numpy
    mod = 'policyengine_core.variables.config' if dialect in ('us', 'uk') else 'openfisca_core.variables.config'
    cfg = __import__(mod, fromlist=['VALUE_TYPES'])
    cfg.VALUE_TYPES[float]['dtype'] = numpy.float64


def run_case(system, test, outputs):
    SimulationBuilder, assert_near = CORE['builder'], CORE['near']
    b = SimulationBuilder()
    b.set_default_period(str(test['period']))
    sim = b.build_from_dict(system, test.get('input') or {})
    margin = test.get('absolute_error_margin', 0.01)
    if isinstance(margin, dict):
        margin = margin.get('default', 0.01)
    #  a relative margin (`relative_error_margin: 0.01`, 1% of the figure),
    #  as OpenFisca's own test runner reads it: then no absolute one
    rel = test.get('relative_error_margin')
    if isinstance(rel, dict):
        rel = rel.get('default')
    actual = {}
    for var in outputs:
        exp = test['output'][var]
        pairs = exp.items() if isinstance(exp, dict) else [(test['period'], exp)]
        for per, e in pairs:
            v = sim.calculate(var, str(per))
            actual[f'{var}@{per}'] = v.tolist()
            if rel is not None and 'absolute_error_margin' not in test:
                assert_near(v, num(e) if not isinstance(e, list) else e, message=f'{var}@{per}: ',
                            relative_error_margin=rel)
            else:
                assert_near(v, num(e) if not isinstance(e, list) else e, margin or 0.01, f'{var}@{per}: ')
    return actual


def equal_months(system, test, outputs):
    """None when each output is the same in every month of the test's year
    (so one month at a twelfth is the year); else why not."""
    b = CORE['builder']()
    b.set_default_period(str(test['period']))
    sim = b.build_from_dict(system, test.get('input') or {})
    y = str(test['period'])
    for var in outputs:
        vals = [sim.calculate(var, f'{y}-{m:02d}').tolist() for m in range(1, 13)]
        if any(abs(sum(map(float, v)) - sum(map(float, vals[0]))) > 0.005 for v in vals):
            return f'{var} is not the same every month of {y}'
    return None


def boundary(system, sim, test, case, info, mid, conv=None):
    """The values the engine computed for the variables just outside the
    programme (a filing status, a head-of-household flag), for each entity of
    the case: {request key: value} for the case's own entity, and, for each
    relation, one {key: value} per member in order."""
    stated = set()
    for k, v in ((conv or {}).get('input') or {}).items():
        if isinstance(v, list):
            if v and all(isinstance(it, dict) for it in v):
                common = set.intersection(*[set(it) for it in v]) if v else set()
                stated |= common
        else:
            stated.add(k)
    outs = [n for n, i in info['variables'].items() if i.get('outside') and f'{mid}#input.{n}' not in stated]
    if not outs and not info.get('by_period'):
        return {}, {}
    per = str(case['period']) if not isinstance(case['period'], dict) else str(case['period']['start'])[:4]
    def at(var):
        vp = str(system.variables[var].definition_period)
        if vp == 'year':
            return per[:4]
        if vp == 'month' and len(per) == 4:
            return per + '-01'
        if vp == 'eternity':
            return 'eternity' if False else per
        return per
    def val(arr, i):
        v = arr[i]
        if getattr(v, 'dtype', None) is not None and str(v.dtype) == 'float32':
            #  the engine's single-precision value as the shortest decimal that
            #  reads back as it (685.8, not 685.7999877929688)
            import numpy as np
            return float(np.format_float_positional(v, unique=True, trim='-'))
        if hasattr(v, 'item'):
            v = v.item()
        if isinstance(v, bytes):
            v = v.decode()
        return v
    first_out = [k for k in test['output'] if k in info['variables']][0]
    qent = system.variables[first_out].entity.key
    own, members = {}, {}
    #  the value of each variable the twin reads for another period, at every
    #  period the case names (roadmap Phase 3b′, item 1): the engine computes
    #  it, as the trace of France's public API would give it
    at_per = {}
    for var in info.get('by_period') or []:
        if var not in system.variables:
            continue
        ent = system.variables[var].entity.key
        #  A value of a group of another kind than the case asks about (the
        #  collective income of a tax household, in a case about a family):
        #  the engine's value of the one group of that kind, which the twin
        #  states of it (`le rev coll donné de foyer_fiscal_1 pour 2016`).
        #  Left out, the twin read the model's default there — 0 — for a
        #  value the engine works out, and the means test of the family
        #  benefits answered nothing of a property income of 20,000 €.
        if ent != qent and ent not in PERSON_ENTITIES and ent not in (case.get('groups') or {}) \
                and f'member_of_{ent}' not in (case.get('members') or {}):
            continue
        vp = str(system.variables[var].definition_period)
        asked = lambda pr: pr[:4] if vp == 'year' else (pr if '-' in pr else pr + '-01') if vp == 'month' else pr
        #  a variable the package computes is the twin's to work out for the
        #  period the case is about: the engine's value there is the answer
        #  the case checks (`rfr`, a root of the income tax), not an input
        #  (a variable left as residue is not: the twin cannot work it out,
        #  and the activity income of the prime d'activité read the IJSS and
        #  the AAH of the case's own month, which nothing stated; unless the
        #  case asks for it, whose value is then the answer)
        residue = (info['variables'].get(var) or {}).get('residue') and var not in (test.get('output') or {})
        own_period = asked(per) if not system.variables[var].is_input_variable() and not residue else None
        vals, per_person = {}, {}
        for pr in case.get('periods') or []:
            ask = asked(pr)
            if ask == own_period:
                continue
            try:
                arr = sim.calculate(var, ask)
                if hasattr(arr, 'decode_to_str'):
                    arr = arr.decode_to_str()
            except Exception:
                continue
            if ent in PERSON_ENTITIES and ent != qent:
                #  a person's value: each member's own, in the member's
                #  record (stated at the top, it was the family's, and of
                #  the first person only)
                ids = list(sim.persons.ids)
                for rel, names in (case.get('members') or {}).items():
                    for j, nm in enumerate(names):
                        i = ids.index(nm) if nm in ids else 0 if len(ids) == 1 == len(names) else None
                        if i is not None:
                            per_person.setdefault((rel, j, len(names)), {})[pr] = val(arr, i)
                continue
            vals[pr] = val(arr, 0)
        if vals:
            at_per[f'{mid}#at_period.{var}'] = vals
        for (rel, j, n), pv in per_person.items():
            members.setdefault(rel, [dict() for _ in range(n)])[j][f'{mid}#at_period.{var}'] = pv
    for var in outs:
        ent = system.variables[var].entity.key
        try:
            arr = sim.calculate(var, at(var))
            if hasattr(arr, 'decode_to_str'):
                arr = arr.decode_to_str()
        except Exception:
            continue
        if var in (info.get('by_period') or []) and ent not in PERSON_ENTITIES and len(arr) == 1:
            #  a value the twin reads for each period: stated at the case's
            #  own period among the others, not also without one (which
            #  asks for a template the twin does not have)
            key = f'{mid}#at_period.{var}'
            names = [pr for pr in (case.get('periods') or []) if pr == at(var) or pr == per]
            at_per.setdefault(key, {})[names[0] if names else at(var)] = val(arr, 0)
        elif ent == qent:
            own[f'{mid}#input.{var}'] = val(arr, 0)
        elif ent not in PERSON_ENTITIES and len(arr) == 1:
            #  a value of the case's one group of another kind (a person's
            #  household): stated at the top, the twin states it of the group
            own[f'{mid}#input.{var}'] = val(arr, 0)
        elif ent not in PERSON_ENTITIES and len(arr) == (case.get('groups') or {}).get(f'member_of_{ent}'):
            #  several groups of that kind (a family's two tax households):
            #  each group's value, in the order the case lists the groups
            gl = own.setdefault(f'{mid}#groups.member_of_{ent}', [dict() for _ in range(len(arr))])
            for gi in range(len(arr)):
                if var in (info.get('by_period') or []):
                    gl[gi].setdefault(f'{mid}#at_period.{var}', {})[at(var)] = val(arr, gi)
                else:
                    gl[gi][f'{mid}#input.{var}'] = val(arr, gi)
        if ent in PERSON_ENTITIES:
            ids = list(sim.persons.ids)
            for rel, names in (case.get('members') or {}).items():
                for j, nm in enumerate(names):
                    #  (a test without groups: its one person, whatever its id)
                    i = ids.index(nm) if nm in ids else 0 if len(ids) == 1 == len(names) else None
                    if i is not None:
                        item = members.setdefault(rel, [dict() for _ in names])[j]
                        if var in (info.get('by_period') or []):
                            #  a person's value read for each period: at the
                            #  case's own period, among the others
                            pn = [pr for pr in (case.get('periods') or []) if pr == at(var) or pr == per]
                            item.setdefault(f'{mid}#at_period.{var}', {})[pn[0] if pn else at(var)] = val(arr, i)
                        else:
                            item[f'{mid}#input.{var}'] = val(arr, i)
    own.update(at_per)
    return own, members


def main(dialect, out, *programmes):
    core(dialect)
    system = load_system(dialect)
    for p in programmes:
        oracle(system, out, p)


def oracle(system, out, programme):
    d = os.path.join(out, 'of')
    info = json.load(open(os.path.join(d, f'{programme}.json')))
    cache = {}
    cases = []
    conv_all = yaml.safe_load(open(os.path.join(d, f'{programme}.test.yaml'))) or []
    for ci, c in enumerate(info['cases']):
        if ci % 50 == 0:
            print(f'  {programme}: case {ci} of {len(info["cases"])}', flush=True)
        f = c['source_file']
        if f not in cache:
            docs = yaml.safe_load(open(f))
            cache[f] = docs if isinstance(docs, list) else [docs]
        test = flat_output(cache[f][c['source_case'] - 1])
        outs = [k for k in test['output'] if k in info['variables']]
        rec = {'name': c['name']}
        try:
            rec['actual'] = run_case(system, test, outs)
            ok = True
            b = CORE['builder']()
            b.set_default_period(str(test['period']))
            sim = b.build_from_dict(system, test.get('input') or {})
            own, members = boundary(system, sim, test, c, info, f"of:{programme}",
                                    conv_all[ci] if ci < len(conv_all) else None)
            if own or members:
                rec['computed'] = {'own': own, 'members': members}
            del sim
        except AssertionError as e:
            ok, rec['why'] = False, 'the engine does not reproduce this test: ' + str(e)[:300]
        except Exception as e:
            ok, rec['why'] = False, 'the engine cannot run this test: ' + str(e)[:300]
        if ok and c.get('twelfths'):
            why = equal_months(system, test, outs)
            if why:
                ok, c['translatable'] = True, False
                c['notes'] = [why]
        if ok and not c['translatable']:
            rec['status'] = 'untranslated'
            rec['why'] = '; '.join(c['notes']) or 'not translated'
        else:
            rec['status'] = 'pass' if ok else 'fail'
        cases.append(rec)
        gc.collect()
    merge_computed(d, programme, cases)
    with open(os.path.join(d, f'{programme}.run.json'), 'w') as fh:
        json.dump({'module': f'of:{programme}', 'engine': info['package'], 'fingerprint': fingerprint(info),
                   'cases': cases}, fh, indent=1, default=str)
    st = [c['status'] for c in cases]
    print(f'{programme}: {st.count("pass")} pass, {st.count("fail")} fail, {st.count("untranslated")} not in the twin\'s reach, of {len(st)}')


def fingerprint(info):
    """The cases as the reader wrote them (their facts and members): a run
    of the engine holds for the same cases only."""
    import hashlib
    keep = [{k: v for k, v in c.items() if k not in ('notes', 'translatable')} for c in info['cases']]
    keep.append(sorted((n, bool(v.get('input')), bool(v.get('outside'))) for n, v in info['variables'].items()))
    keep.append(sorted(info.get('by_period') or []))
    return hashlib.sha256(json.dumps(keep, sort_keys=True, default=str).encode()).hexdigest()


def reuse(out, programme):
    """A new extraction with the last run's results: the values the engine
    computed stated again in the converted tests (the reader changed, the
    tests and the engine did not). Only when the cases are the same ones, in
    the same order: False otherwise, and the engine must run again."""
    d = os.path.join(out, 'of')
    run = json.load(open(os.path.join(d, f'{programme}.run.json')))
    info = json.load(open(os.path.join(d, f'{programme}.json')))
    if run.get('fingerprint') != fingerprint(info):
        print(f'{programme}: the cases changed; the engine runs them again', flush=True)
        return False
    merge_computed(d, programme, run['cases'])
    with open(os.path.join(d, f'{programme}.run.json'), 'w') as fh:
        json.dump(run, fh, indent=1, default=str)
    print(f'{programme}: the last run of the engine reused')
    return True


def engine_answers(cv, rec, margin, twelfths):
    """A test with a margin (`absolute_error_margin: 100`) expects a figure
    near the engine's, and Logical English compares exactly. When the
    engine's figure is a whole number of cents, the twin expects it; when it
    is not (7.6923 where the test says 7.69), the case is left out, with
    the reason."""
    if isinstance(margin, dict):
        margin = margin.get('default')
    if not margin or rec.get('status') != 'pass':
        return
    for key in list((cv.get('output') or {}).keys()):
        var = key.split('#', 1)[-1]
        exp = cv['output'][key]
        got = [v for k, v in (rec.get('actual') or {}).items() if k.split('@')[0] == var]
        if not (len(got) == 1 and isinstance(got[0], list) and len(got[0]) == 1 and isinstance(got[0][0], (int, float))
                and not isinstance(got[0][0], bool) and isinstance(exp, (int, float)) and not isinstance(exp, bool)):
            continue
        v = got[0][0] / 12 if twelfths else got[0][0]
        if abs(v - exp) <= 1e-6:
            continue
        if abs(v - round(v, 2)) <= max(1e-9, 1e-12 * abs(v)):
            #  (the engine runs in double precision: double_precision)
            cv['output'][key] = round(v, 2)
        else:
            rec['status'] = 'untranslated'
            rec['why'] = (f'the test expects {var} = {exp} within {margin}; the engine gives {v:.6g}; '
                          'Logical English compares numbers exactly')


def merge_computed(d, programme, cases):
    tf = os.path.join(d, f'{programme}.test.yaml')
    conv = yaml.safe_load(open(tf)) or []
    #  each converted case with its run, by name (two cases of one name in turn)
    runs = {}
    for rec in cases:
        runs.setdefault(rec['name'], []).append(rec)
    pairs = [(cv, runs[cv['name']].pop(0)) for cv in conv if runs.get(cv.get('name'))]
    #  (the margin and the twelfths are in the information file's cases)
    info = {}
    for c in json.load(open(os.path.join(d, f'{programme}.json'))).get('cases', []):
        info.setdefault(c['name'], []).append(c)
    for cv, rec in pairs:
        c = (info.get(cv['name']) or [{}]).pop(0)
        engine_answers(cv, rec, c.get('absolute_error_margin') or c.get('relative_error_margin'), c.get('twelfths'))
    byp = set(json.load(open(os.path.join(d, f'{programme}.json'))).get('by_period') or [])

    def periodic(key, v, cv):
        """A value the twin reads for each period, stated without one: at
        the case's own period (a template without a period does not exist)."""
        var = key.split('#input.', 1)[1] if '#input.' in key else None
        if var in byp and not isinstance(v, dict):
            return key.replace('#input.', '#at_period.'), {str(cv.get('period')): v}
        return key, v

    for cv, rec in pairs:
        comp = rec.get('computed')
        if not comp:
            continue
        inp = cv.setdefault('input', {})
        for key, v in comp['own'].items():
            if '#at_period.' in key and isinstance(v, dict):
                #  the periods the case does not state itself: the engine's values
                have = inp.setdefault(key, {})
                if isinstance(have, dict):
                    for pr, x in v.items():
                        have.setdefault(pr, x)
                continue
            if '#groups.' in key and isinstance(v, list):
                #  each group's values beside those the case states of it
                have = inp.setdefault(key, [dict() for _ in v])
                for g, extra in zip(have, v):
                    for k2, x in extra.items():
                        if isinstance(x, dict) and isinstance(g.get(k2), dict):
                            for pr, y in x.items():
                                g[k2].setdefault(pr, y)
                        else:
                            g.setdefault(k2, x)
                continue
            key, v = periodic(key, v, cv)
            if isinstance(v, dict) and isinstance(inp.get(key), dict):
                for pr, x in v.items():
                    inp[key].setdefault(pr, x)
                continue
            inp.setdefault(key, v)
        for rel, items in comp['members'].items():
            rk = [x for x in inp if x.endswith('#relation.' + rel)]
            if rk and isinstance(inp[rk[0]], list):
                for it, extra in zip(inp[rk[0]], items):
                    for key, v in extra.items():
                        key, v = periodic(key, v, cv)
                        if '#at_period.' in key and isinstance(v, dict) and isinstance(it.get(key), dict):
                            for pr, x in v.items():
                                it[key].setdefault(pr, x)       # the periods the case does not state itself
                            continue
                        it.setdefault(key, v)
    with open(tf, 'w') as fh:
        yaml.safe_dump(conv, fh, sort_keys=False, allow_unicode=True, width=1000)
    overridable_as_stated(d, programme, conv)


def overridable_as_stated(d, programme, conv):
    """A value the oracle states, which the programme itself computes, is a
    value a case gives: the twin reads what the case gives first and its own
    rule otherwise (`overridable`, as for a value a test gives).

    The reader marks that for the values the *tests* give, before the engine
    has run; the engine's own values are added to the cases afterwards, and a
    case stating a value the program computes without that mark is a case the
    twin builder refuses — which is how the housing allowance lost all 50 of
    its checked expectations when the oracle began stating the values of a
    group of another kind than the case asks about."""
    mf = os.path.join(d, f'{programme}.yaml')
    if not os.path.exists(mf):
        return
    pres = (f'of:{programme}#input.', f'of:{programme}#at_period.')
    stated = set()

    def names(inp):
        for k, v in (inp or {}).items():
            if isinstance(v, list):
                for it in v:
                    if isinstance(it, dict):
                        names(it)
                continue
            for pre in pres:
                if str(k).startswith(pre):
                    stated.add(str(k)[len(pre):])
    for c in conv:
        names(c.get('input'))
    module = yaml.safe_load(open(mf))
    changed = False
    for r in module.get('rules') or []:
        if r.get('kind') == 'derived' and r.get('name') in stated and not r.get('overridable'):
            r['overridable'] = True
            changed = True
    if changed:
        with open(mf, 'w') as fh:
            yaml.safe_dump(module, fh, sort_keys=False, allow_unicode=True, width=1000)


if __name__ == '__main__':
    main(*sys.argv[1:])
