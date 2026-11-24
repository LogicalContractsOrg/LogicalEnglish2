#!/usr/bin/env python3
"""Step 0 of Phase 3b: which formula shapes an OpenFisca / PolicyEngine package uses.

    python3 of_classify.py <package dir> [--only <subpath>] [--json]

For every Variable class: whether it is computed by `adds`/`subtracts`
alone, by formulas, or is an input; for every formula method, whether each
construct is one the translator writes mechanically (arithmetic and
comparisons, `where`/`select`/`max_`/`min_`/`round_`/`not_`/`abs`/`floor`/
`ceil`, entity reads, parameter lookups and indexing, `scale.calc`, group
sums and roles) or residue, with the first residue reason.
"""
import ast, collections, json, os, sys

MECH_CALLS = {'where', 'select', 'max_', 'min_', 'round_', 'not_', 'abs', 'floor', 'ceil', 'round',
              'maximum', 'minimum', 'clip', 'around', 'any', 'all', 'sum', 'max', 'min', 'int', 'float',
              'calc', 'parameters', 'household', 'spm_unit', 'tax_unit', 'family', 'marital_unit',
              'members', 'has_role', 'nb_persons', 'any_', 'sum_', 'ceil_', 'floor_', 'is_in', 'project',
              'max_by', 'min_by', 'value_from_person', 'value_nth_person', 'first_person', 'logical_not',
              'logical_and', 'logical_or', 'zeros_like', 'ones_like', 'isin', 'add', 'aggr', 'last_year',
              'offset', 'this_year', 'first_month', 'period', 'astype', 'in_', 'ones', 'zeros', 'bool'}
RESIDUE_NODES = {ast.For: 'for loop', ast.While: 'while loop', ast.ListComp: 'list comprehension',
                 ast.DictComp: 'dict comprehension', ast.GeneratorExp: 'generator', ast.Lambda: 'lambda',
                 ast.FunctionDef: 'nested function', ast.Try: 'try', ast.With: 'with', ast.SetComp: 'set comprehension',
                 ast.Slice: 'slicing', ast.Starred: 'starred'}


def classify_formula(fn):
    reasons = []
    for node in ast.walk(fn):
        if node is fn:
            continue
        for t, why in RESIDUE_NODES.items():
            if isinstance(node, t):
                reasons.append(why)
        if isinstance(node, ast.If):
            reasons.append('if statement')
        if isinstance(node, ast.Call):
            f = node.func
            name = f.attr if isinstance(f, ast.Attribute) else f.id if isinstance(f, ast.Name) else None
            if isinstance(f, ast.Attribute) and f.attr == 'formula':
                reasons.append('calls another formula')
            elif isinstance(f, ast.Name) and f.id in {'person', 'spm_unit', 'tax_unit', 'household', 'family', 'marital_unit', 'benunit', 'individu', 'famille', 'menage', 'foyer_fiscal'}:
                pass
            elif name is None or name not in MECH_CALLS and not (isinstance(f, ast.Name) and len(f.id) > 0 and f.id[0].islower() and f.id in ('add',)):
                reasons.append(f'call {name}')
    return reasons


def scan(pkg, only=None):
    stats = collections.Counter()
    why = collections.Counter()
    for root, _, files in os.walk(pkg):
        if '/variables' not in root.replace('\\', '/') and '/model' not in root.replace('\\', '/'):   # (openfisca-france: model/)
            continue
        if only and only not in root:
            continue
        for fn in files:
            if not fn.endswith('.py'):
                continue
            try:
                tree = ast.parse(open(os.path.join(root, fn)).read())
            except SyntaxError:
                stats['unparsable files'] += 1
                continue
            for cls in [n for n in tree.body if isinstance(n, ast.ClassDef)]:
                if not any(getattr(b, 'id', '') == 'Variable' or getattr(b, 'attr', '') == 'Variable' for b in cls.bases):
                    continue
                stats['variables'] += 1
                attrs = {t.id for n in cls.body if isinstance(n, ast.Assign) for t in n.targets if isinstance(t, ast.Name)}
                forms = [n for n in cls.body if isinstance(n, ast.FunctionDef) and n.name.startswith('formula')]
                if forms:
                    stats['with formulas'] += 1
                    allmech = True
                    for f in forms:
                        stats['formulas'] += 1
                        r = classify_formula(f)
                        if r:
                            allmech = False
                            stats['residue formulas'] += 1
                            why[r[0]] += 1
                        else:
                            stats['mechanical formulas'] += 1
                    stats['variables all mechanical' if allmech else 'variables with residue'] += 1
                elif attrs & {'adds', 'subtracts'}:
                    stats['adds/subtracts only'] += 1
                else:
                    stats['inputs (no formula)'] += 1
                if 'defined_for' in attrs:
                    stats['defined_for'] += 1
    return stats, why


if __name__ == '__main__':
    args = sys.argv[1:]
    only = None
    if '--only' in args:
        i = args.index('--only'); only = args[i + 1]; del args[i:i + 2]
    s, w = scan(args[0], only)
    print(dict(s))
    f = s['formulas'] or 1
    print(f"mechanical: {s['mechanical formulas']} of {s['formulas']} formulas ({100 * s['mechanical formulas'] / f:.0f}%)")
    print('first residue reason:', w.most_common(12))
