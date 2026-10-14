#!/usr/bin/env python3
"""Build the scenarios of dfe_16_19_funding.le (the showcase) and of
dfe_16_19_funding_tests.le (the test cases) from JSON cases, with their
expected answers.

    python3 check/build_examples.py CASES_DIR REF_OUT.jsonl

CASES_DIR holds the cases in the interface-agreement JSON format (schema.md);
REF_OUT.jsonl is the output of the independent Python reading on them
(run_ref.py). A case is kept only where every output of the program equals
the Python reading's (compare.py), and its expected answers are then written
from the program's answers.
Run from examples/regulatory/dfe_funding/, with LE2's swipl on the path
through ../../../myswipl.sh."""
import json, os, re, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import json2le

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SWIPL = os.path.join(ROOT, 'myswipl.sh')

SHOWCASE = [('full_time', 'sp_vocational_band5_age16_engineering_completed',
             'A 16-year-old on a full-time vocational programme in engineering, completed.'),
            ('t_level', 'tlevel_band9_1730_hours',
             'A T level student in funding band 9 with 1,730 planned hours.'),
            ('t_level_short_of_band_9', 'tlevel_band9_only_1400_hours_drops_to_band7',
             'A T level student in funding band 9 with only 1,400 hours: the band falls to band 7 (page 50).'),
            ('early_leaver', 'early_leaver_below_qualifying_period',
             'A student who leaves before the qualifying period (page 70): not a start, no funding.'),
            ('high_needs', 'sp_age18_hns_600h_band5_high_needs_line',
             'An 18-year-old with high needs on 600 hours: band 5 and the high-needs funding line.'),
            ('condition_of_funding', 'cof_grade3_studying_gcse_cof_type1_min_hours',
             'A student with grade 3 in English, studying GCSE English for the minimum hours (pages 41-45).'),
            ('summer_school', 'summer_school_age15_june_start',
             'A 15-year-old who starts in June: a summer school student (page 69).'),
            ('science_a_levels', 'sp_alevel_science_two_uplift_aims_low_pcw',
             'Two science A levels: the low programme cost weighting of 1.15 (pages 59-60).')]

# The showcase asks every output of the interface agreement (pages 34-36),
# under its Public Name, and the elements of section 4 that no output uses.
SHOWCASE_QUERIES = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'output_queries.txt')).read() + '''
% Elements of section 4 that no output of page 34-36 uses.

query NoGradeCEnglishByYear11 is:
    which learner does not have grade C or above English by year 11.
query NoGradeCMathsByYear11 is:
    which learner does not have grade C or above maths by year 11.
query ContinuingTLevelOSAim is:
    which learner has a continuing T level OS aim.
query LatestTransitionAimStartDate is:
    the latest ESFA 16 to 19 T level transition programme aim start date of which learner is which date.
query LatestTransitionAimSeqNumber is:
    the latest ESFA 16 to 19 T level transition programme aim sequence number of which learner is which number.
query LatestLearningDeliveryStartDate is:
    the latest learning delivery start date of which learner is which date.
query TLevelProgrammeAimRecords is:
    the number of ESFA 16 to 19 T level programme aim records of which learner is which number.
query TransitionProgrammeAimRecords is:
    the number of ESFA 16 to 19 T level transition programme aim records of which learner is which number.
query TLevelOSAimRecords is:
    the number of T level OS aim records of which learner is which number.
'''

def run(args):
    return subprocess.run([SWIPL, '-g', 'use_module(le_kbs)'] + args, cwd=ROOT,
                          capture_output=True, text=True, timeout=7200).stdout

def expectations(path):
    exp = {}
    for line in run([os.path.join(HERE, 'check', 'expectations.pl'), path]).splitlines():
        if line.startswith('{'):
            d = json.loads(line)
            if 'error' in d:
                raise SystemExit(f"{d['scenario']} {d['query']}: {d['error']}")
            exp.setdefault(d['scenario'], []).append((d['query'], d['answers']))
    return exp

def with_expectations(text, exp):
    for scen, items in exp.items():
        lines = ''.join(f'    {q} expects answers [' + ', '.join(json.dumps(a) for a in sorted(ans)) + '].\n'
                        for q, ans in sorted(items))
        text = re.sub(r'(scenario %s is:\n(?:    .*\n)*)' % re.escape(scen), lambda m: m.group(1) + lines, text, count=1)
    return text

def agreeing(cases_dir, ref_out, names):
    """The cases on which the program and the Python reading agree everywhere."""
    tmp = os.path.join(HERE, 'dfe_cases_tmp.le')
    files = [os.path.join(cases_dir, n + '.json') for n in names]
    json2le.main_to(tmp, files)
    le = {}
    for line in run([os.path.join(HERE, 'check', 'run_le.pl'), tmp]).splitlines():
        if line.startswith('{'):
            d = json.loads(line); le[d['case']] = d['out']
    ref = {}
    for line in open(ref_out):
        d = json.loads(line)
        ref['case_' + json2le.const(os.path.splitext(os.path.basename(d['case']))[0])] = d['out']
    def same(a, b):
        if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool) and not isinstance(b, bool):
            return abs(a - b) <= 1e-6 * max(1, abs(a), abs(b))
        return a == b
    keep = []
    for n in names:
        c = 'case_' + json2le.const(n)
        if c in le and c in ref and all(same(v, le[c].get(k)) for k, v in ref[c].items() if not k.startswith('_') and k != 'LearnRefNumber'):
            keep.append(n)
    os.remove(tmp)
    return keep

def main():
    cases_dir, ref_out = sys.argv[1], sys.argv[2]
    names = sorted(os.path.splitext(f)[0] for f in os.listdir(cases_dir) if f.endswith('.json'))
    keep = agreeing(cases_dir, ref_out, names)
    print(f'{len(keep)} of {len(names)} cases agree with the Python reading', file=sys.stderr)

    # the showcase, in the program itself
    prog = os.path.join(HERE, 'dfe_16_19_funding.le')
    text = open(prog).read()
    marker = '% ================================================================ scenarios'
    text = text.split(marker)[0].rstrip('\n') + '\n\n' + marker + '\n'
    text += ('% Eight students, each with the same made-up provider. Their expected answers\n'
             '% were checked against the independent Python reading (README.md).\n\n')
    for name, case, comment in SHOWCASE:
        assert case in keep, case
        scen = json2le.scenario(name, json.load(open(os.path.join(cases_dir, case + '.json'))))
        text += f'% {comment}\n' + scen + '\n'
    text += '% ================================================================ queries\n\n' + SHOWCASE_QUERIES
    open(prog, 'w').write(text)
    final = with_expectations(text, expectations(prog))
    open(prog, 'w').write(final)

    # the test cases, in a file of their own
    tests = os.path.join(HERE, 'dfe_16_19_funding_tests.le')
    json2le.main_to(tests, [os.path.join(cases_dir, n + '.json') for n in keep],
                    header=json2le.TESTS_HEADER, queries=json2le.TESTS_QUERIES)
    final = with_expectations(open(tests).read(), expectations(tests))
    open(tests, 'w').write(final)

if __name__ == '__main__':
    main()
