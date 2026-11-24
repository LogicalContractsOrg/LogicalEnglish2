#!/usr/bin/env python3
"""Run modules written by of_export.pl on openfisca-core: each module's TESTS.

    of_roundtrip_run.py <module.py>...

Prints, per module, how many of its test cases openfisca-core reproduces
(with OF_RT_VERBOSE=1, each case that does not pass).
"""
import importlib.util, os, sys, yaml
from openfisca_core.simulation_builder import SimulationBuilder
from openfisca_core.tools import assert_near

for path in sys.argv[1:]:
    name = os.path.splitext(os.path.basename(path))[0]
    try:
        spec = importlib.util.spec_from_file_location(name, path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        system = mod.system()
    except Exception as e:
        print(f'{name}: the module does not load: {str(e)[:200]}')
        continue
    tests = yaml.safe_load(mod.TESTS) or []
    ok = bad = err = 0
    first = ''
    for t in tests:
        try:
            b = SimulationBuilder()
            b.set_default_period(str(t['period']))
            sim = b.build_from_dict(system, t.get('input') or {})
            for var, exp in (t.get('output') or {}).items():
                assert_near(sim.calculate(var, str(t['period'])), exp, 0.01, f'{var}: ')
            ok += 1
        except AssertionError as e:
            bad += 1
            first = first or f'{t["name"]}: {str(e)[:160]}'
            if os.environ.get('OF_RT_VERBOSE'):
                print(f'  fail {t["name"]}: {str(e)[:300]}')
        except Exception as e:
            err += 1
            first = first or f'{t["name"]}: {type(e).__name__} {str(e)[:160]}'
            if os.environ.get('OF_RT_VERBOSE'):
                print(f'  error {t["name"]}: {type(e).__name__} {str(e)[:300]}')
    print(f'{name}: {ok} pass, {bad} fail, {err} error of {len(tests)}' + (f'  [{first}]' if first else ''))
