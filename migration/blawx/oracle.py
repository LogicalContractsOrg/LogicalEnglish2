#!/usr/bin/env python3
"""The fidelity oracle of the Blawx twins: Blawx's own reasoner, run.

Blawx (blawx/reasoner.py, run_test) answers a test by writing one s(CASP)
file — its preamble (passthrough.py, ldap.py, dates.py with the clock,
aggregates.py, events.py), every section's generated encoding with the
lines after `% BLAWX CHECK DUPLICATES` de-duplicated (variables renamed
A, B, ... in order of appearance) and appended at the end, then the test's
own encoding — and running the test's `?- query.` under library(scasp).
This script does exactly that (the Blawx source it reads is the one in
.cache/, at the commit named in BLAWX_COMMIT), with two differences, both
for reproducibility: the clock is fixed (blawx_now / blawx_today at the
date below, where Blawx reads the machine's), and extra facts may be given
(the scenarios the twin builder generates from the ontology).

    python3 oracle.py <project.yaml> <test_name> [--facts FILE]    -> JSON
    python3 oracle.py <project.yaml> --all                          -> JSON per test
    python3 oracle.py <project.yaml> --batch CASES.json              -> JSON per case
          [--drop-circular] [--drop-abducibles]   (without the circular rules / the
                                                   sections' #abducible lines)
    python3 oracle.py <project.yaml> --query Q [--facts FILE] [--drop-denials]
                                                    -> Q asked of the project (and the facts)

Output: {"test", "query", "variables", "answers": [{"Var": "value", ...}],
         "constraints": [...], "status": "ok" | "no_models" | "error"}
"""
import json, os, re, subprocess, sys, tempfile, ast, warnings
warnings.filterwarnings('ignore', category=SyntaxWarning)

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, '.cache', 'blawx', 'blawx')
BLAWX_COMMIT = '3de892f67854292b304c9a55c5e2cd2058d3d418'   # v1.6.22-alpha, 18 October 2023
CLOCK = 1789344000            # 2026-09-14T00:00:00Z: the day the twins were built
SWIPL = os.environ.get('SWIPL', 'swipl')

def preamble_string(module, name):
    src = open(os.path.join(CACHE, module + '.py'), encoding='utf8').read()
    for node in ast.parse(src).body:
        if isinstance(node, ast.Assign) and any(getattr(t, 'id', None) == name for t in node.targets):
            return ast.literal_eval(node.value)
    raise KeyError(name)

def load_yaml(path):
    import yaml
    return yaml.safe_load(open(path, encoding='utf8'))

def get_variables(query):
    return re.findall(r"[^\w]([A-Z_]\w*)", query)

def simplify_rule(rule):          # reasoner.py's, verbatim in effect
    variables = get_variables(rule)
    replacements = ['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q']
    for index, var in enumerate(variables):
        rule = rule.replace(var, replacements[index])
    return rule

def drop_denials(text):
    """The source without its `false :- ...` constraints (to ask whether a
    case violates one: with the constraint in place s(CASP) has no model)."""
    out, skipping = [], False
    for line in text.splitlines():
        if not skipping and line.startswith('false :-'):
            skipping = True
        if skipping:
            if line.rstrip().endswith('.'):
                skipping = False
            continue
        out.append(line)
    return '\n'.join(out)

CIRCULAR = re.compile(r'^according_to\((\w+),(\w+),([A-Z]\w*)\) :- \2\(\3\)')

def drop_circular(text):
    """The source without its rules that need their own conclusion
    (`according_to(S,p,X) :- p(X), ...`): they add nothing in the least
    model or the stable models, but s(CASP) 1.1.4 proves nothing at all of a
    predicate caught in one (a loop with a disequality in Rule 34)."""
    out, skipping = [], False
    for line in text.splitlines():
        if not skipping and CIRCULAR.match(line):
            skipping = True
        if skipping:
            if line.rstrip().endswith('.'):
                skipping = False
            continue
        out.append(line)
    return '\n'.join(out)

def drop_abducibles(text):
    return '\n'.join(l for l in text.splitlines() if not l.startswith('#abducible'))

FLAGS = set()

def assemble(project, test, extra_facts='', no_denials=False):
    wss = [m['fields'] for m in project if m['model'] == 'blawx.workspace']
    ruleset, unique_rules = '', []
    def add(lines):
        nonlocal ruleset
        register = False
        for line in lines:
            if line == '% BLAWX CHECK DUPLICATES':
                register = True
                continue
            elif register:
                register = False
                s = simplify_rule(line)
                if s not in unique_rules:
                    unique_rules.append(s)
                continue
            else:
                ruleset += line + '\n'
    for ws in wss:
        ruleset += '\n\n'
        enc = drop_denials(ws['scasp_encoding']) if no_denials else ws['scasp_encoding']
        if 'circular' in FLAGS: enc = drop_circular(enc)
        if 'abducibles' in FLAGS: enc = drop_abducibles(enc)
        add(enc.splitlines())
    ruleset += '\n\n'
    add(test['scasp_encoding'].splitlines())
    for ur in unique_rules:
        ruleset += ur + '\n'
    query = None
    for line in test['scasp_encoding'].splitlines():
        if line.startswith('?- '):
            query = line[3:-1]
    now = 'blawx_now(datetime(%d)).\nblawx_today(date(%d)).\n' % (CLOCK, CLOCK)
    text = ':- use_module(library(scasp)).\n\n'
    for mod, name in [('passthrough', 'blawx_passthrough'), ('ldap', 'ldap_code'),
                      ('dates', 'scasp_dates'), (None, now), ('aggregates', 'scasp_aggregates'),
                      ('events', 'ec_code')]:
        text += (preamble_string(mod, name) if mod else name) + '\n\n'
    #  Blawx writes the test's `?- query.` line into the file too, where
    #  loading it runs it as a directive that fails; it asks the query
    #  afterwards. Here the line is left out of the file, and asked the same.
    ruleset = '\n'.join(l for l in ruleset.splitlines() if not l.startswith('?- '))
    text += ruleset + '\n' + extra_facts + '\n'
    return text, query

DRIVER = r'''
:- use_module(library(scasp)).
:- use_module(library(time)).
:- initialization(main, main).
main :-
    getenv('BLAWX_PROGRAM', File), getenv('BLAWX_QUERY', QueryText),
    catch(load_files(File, [silent(true)]), E, (print_message(error, E))),
    term_string(Q, QueryText, [variable_names(Bs)]),
    (   catch(call_with_time_limit(60,
            findall(Row-Cs, ( scasp(Q, [source(false)]), row(Bs, Row, Cs) ), Rows)), E2,
            ( print_message(error, E2), Rows = error ))
    ->  true ; Rows = [] ),
    (   Rows == error -> format('~w~n', ['{"status":"error"}'])
    ;   sort(Rows, Sorted),
        findall(_{row: R, constraints: C}, member(R-C, Sorted), Ds),
        json_write_dict(current_output, _{status: ok, rows: Ds}, [width(0)]), nl
    ).
row(Bs, Row, Cs) :-
    findall(N-V, member(N=V, Bs), Pairs),
    pairs_values(Pairs, Vs),
    copy_term(Vs, Vs1, Gs),
    findall(N-S, ( nth1(I, Pairs, N-_), nth1(I, Vs1, V1), value_string(V1, S) ), Row0),
    dict_pairs(Row, _, Row0),
    maplist([G, S]>>format(string(S), "~q", [G]), Gs, Cs).
value_string(V, S) :- ( var(V) -> S = "_" ; format(string(S), "~q", [V]) ).
'''

def run_query(text, query):
    with tempfile.TemporaryDirectory() as d:
        pf = os.path.join(d, 'program.pl'); open(pf, 'w', encoding='utf8').write(text)
        df = os.path.join(d, 'driver.pl'); open(df, 'w').write(DRIVER)
        env = dict(os.environ, BLAWX_PROGRAM=pf, BLAWX_QUERY=query)
        p = subprocess.run([SWIPL, '-q', df], capture_output=True, text=True, timeout=300, env=env)
        out = p.stdout.strip().splitlines()
        if not out:
            return {'status': 'error', 'stderr': p.stderr[-2000:]}
        r = json.loads(out[-1])
        if r.get('status') == 'error':
            r['stderr'] = p.stderr[-2000:]
        return r

def answer(project, test, extra_facts='', no_denials=False):
    text, query = assemble(project, test, extra_facts, no_denials)
    if query is None:
        return {'test': test['test_name'], 'query': None, 'status': 'no_query', 'answers': []}
    r = run_query(text, query)
    rows = r.get('rows', [])
    return {'test': test['test_name'], 'query': query,
            'variables': get_variables(' ' + query),
            'status': r['status'] if rows or r['status'] != 'ok' else 'no_answers',
            'answers': [x['row'] for x in rows],
            'constraints': [x['constraints'] for x in rows],
            'stderr': r.get('stderr', '')}

def main():
    args = sys.argv[1:]
    if '--drop-circular' in args: FLAGS.add('circular')
    if '--drop-abducibles' in args: FLAGS.add('abducibles')     # the sections' #abducible lines
    project = load_yaml(args[0])
    tests = [m['fields'] for m in project if m['model'] == 'blawx.blawxtest']
    extra = ''
    if '--facts' in args:
        extra = open(args[args.index('--facts') + 1], encoding='utf8').read()
    if '--query' in args:     # a generated scenario: its facts and a query of our own
        q = args[args.index('--query') + 1]
        fake = {'test_name': 'generated', 'scasp_encoding': extra + '\n?- ' + q + '.'}
        print(json.dumps(answer(project, fake, no_denials='--drop-denials' in args)))
        return
    if '--batch' in args:     # generated cases: [{"id", "facts", "query"}] -> answers, two at a time
        from concurrent.futures import ThreadPoolExecutor
        cases = json.load(open(args[args.index('--batch') + 1], encoding='utf8'))
        def one(c):
            fake = {'test_name': c['id'], 'scasp_encoding': c['facts'] + '\n?- ' + c['query'] + '.'}
            return answer(project, fake)
        with ThreadPoolExecutor(max_workers=2) as ex:
            print(json.dumps(list(ex.map(one, cases))))
        return
    if len(args) > 1 and args[1] == '--all':
        print(json.dumps([answer(project, t) for t in tests]))
    else:
        t = next(t for t in tests if t['test_name'] == args[1])
        print(json.dumps(answer(project, t, extra)))

if __name__ == '__main__':
    main()
