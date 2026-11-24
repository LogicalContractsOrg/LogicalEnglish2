#!/usr/bin/env python3
"""The housing allowance written twice, checked against itself (roadmap
Phase 3b′, step 5).

openfisca-france's `aides_logement` and Catala's housing allowance example
(`CalculAidePersonnaliséeLogementLocatif`, the Catala twin `apl_locatif`)
encode the same law. Neither source checks one against the other. This
script writes the same rental situations for both twins:

    of_crosscheck.py gen     (in .cache/venv-fr) the situations, as
                             openfisca-france tests whose expected values
                             the package's own engine computes
                             (runs/croise/aides_logement_croise.yaml, the
                             tests of the programme `aides_logement_croise`
                             of corpus.pl), and as scenarios of a copy of
                             the Catala twin (runs/croise/apl_locatif_croise.le)
    of_crosscheck.py report  the answers of both twins side by side
                             (runs/croise/report.md), from the output of
                             LE2's test runner on each program

A situation is a household renting its home in metropolitan France, with
an APL (the rent agreement of a conventionné dwelling): a single person or
a couple, with up to three children under 21, in one of the three zones,
at a month of 2022 to 2024, with a monthly rent and yearly resources (a
multiple of 100: the Catala programme is given its resources rounded, as
the law rounds them).
"""
import itertools, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'runs', 'croise')
LE2 = os.environ.get('LE2_DIR', os.path.abspath(os.path.join(HERE, '..', '..')))
#  The private place of the OpenFisca twins (AGPL-3.0 sources: not published).
PRIVATE = os.environ.get('LE_PRIVATE_TWINS_DIR', os.path.join(os.path.dirname(LE2), 'lpsPlus'))
CATALA_TWIN = os.path.join(LE2, 'examples/migration/catala/apl_locatif/apl_locatif.le')

#  The quantities both twins name: the openfisca-france variable, the
#  Catala twin's query and the words of its answer.
SHARED = [
    ('aide_logement_loyer_plafond', 'q_plafond_loyer_d823_16_2', 'le plafond loyer d823 16 2 est'),
    ('aide_logement_charges', 'q_montant_forfaitaire_charges_d823_16', 'le montant forfaitaire charges d823 16 est'),
    ('aide_logement_participation_minimale', 'q_participation_minimale', 'la participation minimale est'),
    ('aide_logement_taux_famille', 'q_taux_composition_familiale', 'le taux composition familiale est'),
    ('aide_logement_participation_personnelle', 'q_participation_personnelle', 'la participation personnelle est'),
]


def situations():
    months = ['2022-02', '2022-11', '2023-03', '2024-03']
    out = []
    for i, (month, zone, couple, kids, rent, res) in enumerate(itertools.product(
            months, (1, 2, 3), (False, True), (0, 1, 3), (450, 900), (9000, 24000))):
        #  one in eight of the 576 combinations, spread over every factor
        if i % 8 != (i // 8) % 8:
            continue
        out.append(dict(month=month, zone=zone, couple=couple, kids=kids, rent=rent, res=res))
    return out


def name_of(s):
    return (f"croise_{s['month'].replace('-', '_')}_zone{s['zone']}_{'couple' if s['couple'] else 'seul'}"
            f"_{s['kids']}enf_loyer{s['rent']}_res{s['res']}")


def of_test(s):
    adults = ['parent1', 'parent2'] if s['couple'] else ['parent1']
    kids = [f'enfant{k + 1}' for k in range(s['kids'])]
    individus = {'parent1': {'age': 40}}
    if s['couple']:
        individus['parent2'] = {'age': 38}
    for k, e in enumerate(kids):
        individus[e] = {'age': 4 + 3 * k}
    menage = {'personne_de_reference': 'parent1', 'zone_apl': f"zone_{s['zone']}", 'loyer': s['rent'],
              'statut_occupation_logement': 'locataire_vide', 'logement_conventionne': True}
    if s['couple']:
        menage['conjoint'] = 'parent2'
    if kids:
        menage['enfants'] = kids
    famille = {'parents': adults, 'aide_logement_base_ressources': s['res']}
    if kids:
        famille['enfants'] = kids
    foyer = {'declarants': adults}
    if kids:
        foyer['personnes_a_charge'] = kids
    return {'name': name_of(s), 'period': s['month'],
            'input': {'individus': individus, 'famille': famille, 'menage': menage, 'foyer_fiscal': foyer},
            'output': {}}


def gen():
    import yaml
    sys.path.insert(0, HERE)
    import of_extract, of_oracle
    of_oracle.core('france')
    system = of_extract.load_system('france')
    from openfisca_core.simulation_builder import SimulationBuilder
    os.makedirs(OUT, exist_ok=True)
    tests, facts = [], []
    for s in situations():
        t = of_test(s)
        b = SimulationBuilder()
        b.set_default_period(s['month'])
        sim = b.build_from_dict(system, t['input'])
        for var, _, _ in SHARED + [('aide_logement_montant', None, None)]:
            v = float(sim.calculate(var, s['month'])[0])
            t['output'][var] = round(v, 6)
        tests.append(t)
        facts.append((s, t['output']))
    with open(os.path.join(OUT, 'aides_logement_croise.yaml'), 'w') as f:
        yaml.safe_dump(tests, f, sort_keys=False, allow_unicode=True, width=1000)
    #  the same situations, as scenarios of the Catala twin; their expected
    #  values are openfisca-france's, so a failure is a disagreement
    src = open(CATALA_TWIN).read()
    lines = [src.rstrip(), '', '% Les situations du contrôle croisé (of_crosscheck.py) : les valeurs attendues sont celles',
             '% du moteur d\'openfisca-france ; une valeur différente est un désaccord entre les deux codages.', '']
    for s, outv in facts:
        lines.append(f"scénario {name_of(s)} est:")
        lines.append(f"    la date courante est {s['month']}-01.")
        lines.append(f"    le loyer principal base est {s['rent']}.")
        lines.append(f"    le nombre personnes à charge est {s['kids']}.")
        lines.append(f"    le ressources ménage arrondies est {s['res']}.")
        lines.append("    la réduction loyer solidarité est 0.")
        lines.append('    la résidence est "Métropole".')
        lines.append(f"    la situation familiale calcul apl est \"{'Couple' if s['couple'] else 'PersonneSeule'}\".")
        lines.append('    le type aide est "AidePersonnaliséeLogement".')
        lines.append(f"    le zone est \"Zone{s['zone']}\".")
        for var, q, words in SHARED:
            v = ('%.6f' % outv[var]).rstrip('0').rstrip('.').replace('.', ',')
            lines.append(f'    {q} attend les réponses ["{words} {v}"].')
        lines.append('')
    with open(os.path.join(OUT, 'apl_locatif_croise.le'), 'w') as f:
        f.write('\n'.join(lines) + '\n')
    json.dump([dict(s, name=name_of(s), engine=o) for s, o in facts],
              open(os.path.join(OUT, 'situations.json'), 'w'), indent=1)
    print(f'{len(facts)} situations written to {OUT}')


def run_le(path, tag):
    """LE2's test runner on a program; its output kept in runs/croise/<tag>.out
    (read again, rather than run again, with OF_CROSS_REUSE=1)."""
    keep = os.path.join(OUT, f'{tag}.out')
    if os.environ.get('OF_CROSS_REUSE') and os.path.exists(keep):
        return open(keep).read()
    cmd = ['./myswipl.sh', '-g', f"use_module(le_kbs), runTestsFor('{path}', R), print_test_result(R), halt."]
    p = subprocess.run(cmd, cwd=LE2, capture_output=True, text=True, timeout=3600)
    out = p.stdout + p.stderr
    with open(keep, 'w') as f:
        f.write(out)
    return out


def parse(out):
    """{(scenario, query): ('pass'|'fail'|'error', actual text)} from LE2's test runner."""
    res = {}
    lines = out.splitlines()
    for i, l in enumerate(lines):
        m = re.match(r'\s*(PASS|FAIL): (\S+) \((.+)\)\s*$', l)
        if m:
            actual = None
            if m.group(1) == 'FAIL':
                for k in range(i + 1, min(i + 5, len(lines))):
                    a = re.match(r'\s*Actual:\s*\[(.*)\]', lines[k])
                    if a:
                        actual = a.group(1)
                        break
            res[(m.group(3), m.group(2))] = (m.group(1).lower(), actual)
            continue
        m = re.match(r'\s*ERROR: error\((\S+?),(.+?),', l)
        if m:
            res[(m.group(2), m.group(1))] = ('error', l.strip()[:200])
    return res


def number_in(text):
    if not text:
        return None
    m = re.search(r'(-?\d+(?:[.,]\d+)?)\s*$', text.strip())
    return float(m.group(1).replace(',', '.')) if m else None


def report():
    sits = json.load(open(os.path.join(OUT, 'situations.json')))
    of_le = os.path.join(PRIVATE, 'examples/migration/openfisca/aides_logement_croise/aides_logement_croise.le')
    of_res = parse(run_le(of_le, 'openfisca_twin'))
    cat_res = parse(run_le(os.path.join(OUT, 'apl_locatif_croise.le'), 'catala_twin'))
    rows, tally = [], {}
    for s in sits:
        for var, q, _ in SHARED:
            eng = s['engine'][var]
            oq = 'q_' + var
            #  the OpenFisca twin's scenario is named after the test
            o = next((v for (sc, qq), v in of_res.items() if qq == oq and sc.startswith(s['name'][:40])), None)
            c = cat_res.get((s['name'], q))
            ov = None if o is None else (eng if o[0] == 'pass' else number_in(o[1]))
            cv = None if c is None else (eng if c[0] == 'pass' else number_in(c[1]))
            agree = ov is not None and cv is not None and abs(ov - cv) <= 1e-6
            key = var
            t = tally.setdefault(key, {'agree': 0, 'disagree': 0, 'unanswered': 0})
            t['agree' if agree else 'unanswered' if ov is None or cv is None else 'disagree'] += 1
            rows.append((s['name'], var, eng, ov, cv, 'yes' if agree else '—' if ov is None or cv is None else 'NO'))
    with open(os.path.join(OUT, 'report.md'), 'w') as f:
        f.write('# The housing allowance, two encodings compared\n\n')
        f.write(f'{len(sits)} situations (of_crosscheck.py). For each, the value of openfisca-france\'s engine, '
                'of the OpenFisca twin and of the Catala twin.\n\n')
        f.write('| Quantity | Twins agree | Disagree | Not answered by one |\n|---|---|---|---|\n')
        for k, t in tally.items():
            f.write(f"| `{k}` | {t['agree']} | {t['disagree']} | {t['unanswered']} |\n")
        f.write('\n| Situation | Quantity | Engine | OpenFisca twin | Catala twin | Agree |\n|---|---|---|---|---|---|\n')
        for r in rows:
            f.write('| ' + ' | '.join('' if x is None else str(x) for x in r) + ' |\n')
    print(json.dumps(tally, indent=1))


if __name__ == '__main__':
    {'gen': gen, 'report': report}[sys.argv[1]]()
