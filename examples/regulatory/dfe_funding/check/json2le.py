#!/usr/bin/env python3
"""Turn test cases in the interface-agreement JSON format (schema.md) into one
Logical English file of scenarios that includes dfe_16_19_funding.le.

    python3 json2le.py OUT.le case1.json case2.json ...

Each case becomes a scenario named after its file. A field absent from the
JSON is left unstated: OIA's "unknown"."""
import json, re, sys, os

def const(s):
    return re.sub(r'[^a-z0-9]+', '_', str(s).lower()).strip('_') or 'x'

def text(v):
    return '"' + str(v).replace('"', "'") + '"'

def num(v):
    return repr(v) if isinstance(v, float) else str(v)

def val(v, kind):
    if kind == 'text':
        return text(v)
    if kind == 'date':
        return str(v)
    return num(v)

PROVIDER = [('RetentionFactor', "the provider's retention factor is {}."),
            ('ProgrammeWeighting', "the provider's programme weighting is {}."),
            ('AreaCostFactor1618', "the provider's 16 to 18 area cost factor is {}."),
            ('HistoricLargeProgrammeProportion', "the provider's historic large programme proportion is {}."),
            ('DisadvantageProportion', "the provider's disadvantage proportion is {}."),
            ('EnglishandMathsProportion', "the provider's English and maths proportion is {}.")]
LEARNER = [('DateOfBirth', 'date', 'the date of birth of {L} is {v}.'),
           ('EngGrade', 'text', 'the GCSE English grade of {L} is {v}.'),
           ('MathGrade', 'text', 'the GCSE maths grade of {L} is {v}.'),
           ('LrnFAM_ECF', 'num', 'the ECF FAM code of {L} is {v}.'),
           ('LrnFAM_EDF1', 'num', 'the EDF FAM code 1 of {L} is {v}.'),
           ('LrnFAM_EDF2', 'num', 'the EDF FAM code 2 of {L} is {v}.'),
           ('LrnFAM_EHC', 'num', 'the EHC FAM code of {L} is {v}.'),
           ('LrnFAM_HNS', 'num', 'the HNS FAM code of {L} is {v}.'),
           ('LrnFAM_MCF', 'num', 'the MCF FAM code of {L} is {v}.'),
           ('LrnFAM_NLM1', 'num', 'the NLM FAM code 1 of {L} is {v}.'),
           ('LrnFAM_NLM2', 'num', 'the NLM FAM code 2 of {L} is {v}.'),
           ('LrnFAM_EMH', 'num', 'the EMH FAM code of {L} is {v}.'),
           ('LrnFAM_MMH', 'num', 'the MMH FAM code of {L} is {v}.'),
           ('PlanLearnHours', 'num', 'the planned learning hours of {L} is {v}.'),
           ('PlanEEPHours', 'num', 'the planned employability, enrichment and pastoral hours of {L} is {v}.'),
           ('PostcodeDisadvantageUplift', 'num', 'the postcode disadvantage uplift of {L} is {v}.')]
DELIVERY = [('LearnAimRef', 'text', 'the learning aim reference of {D} is {v}.'),
            ('AimType', 'num', 'the aim type of {D} is {v}.'),
            ('AimSeqNumber', 'num', 'the aim sequence number of {D} is {v}.'),
            ('FundModel', 'num', 'the funding model of {D} is {v}.'),
            ('ProgType', 'num', 'the programme type of {D} is {v}.'),
            ('LearnStartDate', 'date', 'the learning start date of {D} is {v}.'),
            ('LearnPlanEndDate', 'date', 'the learning planned end date of {D} is {v}.'),
            ('LearnActEndDate', 'date', 'the learning actual end date of {D} is {v}.'),
            ('CompStatus', 'num', 'the completion status of {D} is {v}.'),
            ('WithdrawReason', 'num', 'the withdrawal reason of {D} is {v}.'),
            ('LearnAimRefTitle', 'text', 'the learning aim reference title of {D} is {v}.'),
            ('LearnAimRefType', 'text', 'the learning aim reference type of {D} is {v}.'),
            ('AwardOrgCode', 'text', 'the awarding organisation code of {D} is {v}.'),
            ('EFACOFType', 'num', 'the ESFA condition of funding type of {D} is {v}.'),
            ('SectorSubjectAreaTier2', 'num', 'the sector subject area tier 2 of {D} is {v}.'),
            ('DelLocPostcode', 'text', 'the delivery location postcode of {D} is {v}.')]

def g(d, *keys):
    for k in keys:
        if k in d and d[k] is not None:
            return d[k]
    return None

def scenario(name, case):
    out = []
    prov = case.get('provider', {})
    for k, f in PROVIDER:
        if prov.get(k) is not None:
            out.append(f.format(num(prov[k])))
    if prov.get('SpecialistResources') is True:
        out.append('the provider has specialist resources.')
    for i, r in enumerate(case.get('postcode_specialist_resources', []), 1):
        R = f'{name}_postcode_record_{i}'
        out.append(f'{R} is a postcode specialist resource record.')
        for k, f in [('PostcodeSpecResPostcode', 'the postcode of {R} is {v}.'),
                     ('PostcodeSpecResSpecialistResources', 'the specialist resources of {R} is {v}.')]:
            if r.get(k) is not None:
                out.append(f.format(R=R, v=text(r[k])))
        for k, f in [('PostcodeSpecResEffectiveFrom', 'the effective from date of {R} is {v}.'),
                     ('PostcodeSpecResEffectiveTo', 'the effective to date of {R} is {v}.')]:
            if r.get(k) is not None:
                out.append(f.format(R=R, v=r[k]))
    lr = case['learner']
    L = 'learner_' + const(lr.get('LearnRefNumber', name))
    out.append(f'{L} is a learner.')
    for k, kind, f in LEARNER:
        if lr.get(k) is not None:
            out.append(f.format(L=L, v=val(lr[k], kind)))
    for j, d in enumerate(lr.get('LearningDeliveries', []), 1):
        D = f"{L}_aim_{const(d.get('AimSeqNumber', j))}"
        out.append(f'{L} has {D}.')
        for k, kind, f in DELIVERY:
            if d.get(k) is not None:
                out.append(f.format(D=D, v=val(d[k], kind)))
        for fam in d.get('FAMs', []):
            if fam.get('LearnDelFAMType') is not None and fam.get('LearnDelFAMCode') is not None:
                out.append(f"{D} has a FAM of type {text(fam['LearnDelFAMType'])} with code {text(fam['LearnDelFAMCode'])}.")
        cats = list(d.get('LARSCategories', []))
        if not cats and d.get('LearnDelCatRef') is not None:
            cats = [{'LearnDelCatRef': d['LearnDelCatRef']}]
        for c in cats:
            if c.get('LearnDelCatRef') is not None:
                out.append(f"{D} has a LARS category with reference {num(c['LearnDelCatRef'])}.")
        for i, v in enumerate(d.get('LARSValidities', []), 1):
            V = f'{D}_validity_{i}'
            out.append(f'{D} has {V} as a LARS validity.')
            if v.get('ValidityCategory') is not None:
                out.append(f"the category of {V} is {text(v['ValidityCategory'])}.")
            if v.get('ValidityStartDate') is not None:
                out.append(f"the validity start date of {V} is {v['ValidityStartDate']}.")
            if v.get('ValidityLastNewStartDate') is not None:
                out.append(f"the last date for new starts of {V} is {v['ValidityLastNewStartDate']}.")
        for i, p in enumerate(d.get('LARSProgrammeFunding', []), 1):
            P = f'{D}_funding_{i}'
            out.append(f'{D} has {P} as a LARS programme funding record.')
            if p.get('PFTlevelFundingBand') is not None:
                out.append(f"the funding band of {P} is {text(p['PFTlevelFundingBand'])}.")
            if p.get('PFTlevelPCW') is not None:
                out.append(f"the PCW of {P} is {num(p['PFTlevelPCW'])}.")
            code = g(p, 'PFProgrammeCode', 'ProgrammeCode')
            if code is None:
                code = d.get('PFProgrammeCode')
            if code is not None:
                out.append(f"the programme code of {P} is {num(code)}.")
            if p.get('PFEffectiveFrom') is not None:
                out.append(f"the effective from date of {P} is {p['PFEffectiveFrom']}.")
            if p.get('PFEffectiveTo') is not None:
                out.append(f"the effective to date of {P} is {p['PFEffectiveTo']}.")
        for h in d.get('HRSRecords', []):
            if None not in (h.get('HRSType'), h.get('HRSCode'), h.get('HRSAmount')):
                out.append(f"{D} has an hours record of type {text(h['HRSType'])} with code {num(h['HRSCode'])} and amount {num(h['HRSAmount'])}.")
    return f'scenario {name} is:\n' + ''.join('    ' + l + '\n' for l in out)

HEADER = '''the target language is: prolog.

the knowledge base dfe_cases includes these resources:
    dfe_16_19_funding.

the knowledge base dfe_cases includes:

'''

TESTS_HEADER = """% The test cases of the DfE 16 to 19 funding calculation 2026 to 2027.
%
% Each scenario is one test case of an independent reading of the rules, written
% in Python from the same pages (README.md). The expected answers are the
% answers of dfe_16_19_funding.le, kept only for the cases where every output
% of the program equals the Python reading's. This file is written by
% check/build_examples.py: do not edit it by hand.

the target language is: prolog.

the knowledge base dfe_16_19_funding_tests includes these resources:
    dfe_16_19_funding.

the knowledge base dfe_16_19_funding_tests includes:

"""

# The outputs the tests check: the ones that decide the money, and the
# condition of funding.
TESTS_QUERIES = """query FundLine is:
    the funding line type of which learner is which funding line type.

query RateBand is:
    the rate band of which learner is which band.

query NatRate is:
    the national rate of which learner is which amount.

query OnProgPayment is:
    the on programme funding of which learner is which amount.

query StartFund is:
    which learner is a start.

query ConditionOfFundingEnglish is:
    the English condition of funding status of which learner is which status.

query ConditionOfFundingMaths is:
    the maths condition of funding status of which learner is which status.

query ProgWeightNew is:
    the new programme weighting of which learner is which number.

query RetentNew is:
    the new retention status of which learner is which number.

query LearnerEnglishMathsInstances is:
    the English and maths instances of which learner is which number.
"""

def main_to(out, files, header=HEADER, queries=None):
    parts = [header]
    for f in files:
        name = 'case_' + const(os.path.splitext(os.path.basename(f))[0])
        parts.append(scenario(name, json.load(open(f))) + '\n')
    if queries is None:
        queries = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'output_queries.txt')).read()
    parts.append(queries)
    open(out, 'w').write(''.join(parts))

def main():
    main_to(sys.argv[1], sys.argv[2:])

if __name__ == '__main__':
    main()
