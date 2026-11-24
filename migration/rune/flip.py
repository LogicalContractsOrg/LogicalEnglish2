"""rune.md §7 question 3, "What changes if...?": one fact of a trade flipped,
DRR's Java run on the trade before and after, and the twin's scenarios made
from both (build.pl, group flips) so that the twin is measured against DRR on
the flipped trades too.

    python3 flip.py        # writes .cache/chain/input/flips/*.json and,
                           # with DRR's Java, .cache/chain/output/<report>/flips/*.json

Each flip is a name, the base instruction (a file of DRR's test pack) and a
change of its EMIR party information (regime EMIR, supervisory body ESMA).
"""
import copy, json, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, '.cache')
PACK = 'drr/enrich/output/fpml-record-keeping-to-reportable-event/transaction-report-instruction-test-pack-default'
BASE = os.path.join(CACHE, PACK, 'credit/Credit-Index-CDX-ex02.json')
REPORTS = {
    'esma-emir-trade': 'drr.regulation.esma.emir.refit.trade.reports.ESMAEMIRTradeReportFunction',
}

def emir_parties(d):
    for j in d['reportableInformation']['jurisdictionInformation']:
        if j.get('regimeName', {}).get('value') == 'EMIR':
            return j['partyInformation']
    raise ValueError('no EMIR jurisdiction')

def as_is(d):
    pass

def both_mandatory(d):
    # the counterparties become subject to the clearing obligation as well as
    # the product (EMIR article 4: a financial counterparty above the
    # clearing threshold)
    for p in emir_parties(d):
        p['mandatorilyClearable'] = 'ProductAndCptyMandatory'

def below_threshold(d):
    # the counterparties no longer exceed the clearing threshold
    for p in emir_parties(d):
        p['esmaPartyInformation']['exceedsClearingThreshold'] = False

FLIPS = [('cdx02_as_is', as_is), ('cdx02_both_mandatory', both_mandatory),
         ('cdx02_below_threshold', below_threshold)]

def main():
    base = json.load(open(BASE))
    ind = os.path.join(CACHE, 'chain/input/flips')
    os.makedirs(ind, exist_ok=True)
    for name, f in FLIPS:
        d = copy.deepcopy(base)
        f(d)
        json.dump(d, open(os.path.join(ind, name + '.json'), 'w'), indent=1)
    cp = open(os.path.join(CACHE, 'classpath.txt')).read().strip()
    for rep, fn in REPORTS.items():
        outd = os.path.join(CACHE, 'chain/output', rep, 'flips')
        os.makedirs(outd, exist_ok=True)
        pairs = ''.join(f"{os.path.join(ind, n + '.json')}\t{os.path.join(outd, n + '.json')}\n" for n, _ in FLIPS)
        r = subprocess.run(['java', '-cp', cp, 'DrrOracle', fn, 'drr.regulation.common.TransactionReportInstruction'],
                           input=pairs, capture_output=True, text=True, cwd=CACHE)
        print(rep, r.stdout.strip().replace('\n', ' | ')[:300])
        for n, _ in FLIPS:
            o = json.load(open(os.path.join(outd, n + '.json')))
            print('  ', n, {k: o.get(k) for k in ['clearingObligation', 'clearingThresholdOfCounterparty1', 'clearingThresholdOfCounterparty2', 'cleared']})

if __name__ == '__main__':
    main()
