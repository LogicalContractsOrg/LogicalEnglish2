#!/usr/bin/env python3
"""Golden and regression tests for rosetta2json. Run from the repo root:

    python3 tools/rosetta2json/test_rosetta2json.py
"""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from rosetta2json import convert  # noqa: E402

HERE = Path(__file__).resolve().parent
# The demo model is a copy of cdmLOG's (testdata/demo); the CDM is the one DRR
# brings (fetch_sources.sh), or $CDM_ROSETTA.
DEMO = HERE / 'testdata' / 'demo'
CDM = Path(os.environ.get('CDM_ROSETTA', HERE.parent / '.cache' / 'drr' / 'drr' / 'rosetta'))


def convert_dir(src):
    tmp = tempfile.mkdtemp(prefix='r2j-test-')
    convert(src, tmp)
    return {p.stem: json.loads(p.read_text())
            for p in Path(tmp).glob('*.json')}


class DemoGolden(unittest.TestCase):
    """The demo model is the canonical conversion example (examples/CLAUDE.md)."""

    @classmethod
    def setUpClass(cls):
        cls.out = convert_dir(DEMO)
        cls.model = cls.out['demo.emissions.model']
        cls.golden = json.loads(
            (DEMO / 'demo.emissions.model.json').read_text())

    def test_component_sets_match_golden(self):
        for kind in ('types', 'enums', 'choices', 'functions', 'typeAliases'):
            self.assertEqual(set(self.model.get(kind, {})),
                             set(self.golden.get(kind, {})), kind)

    def test_attribute_shape(self):
        attr = self.model['types']['Engine']['attributes']['engineType']
        self.assertEqual(attr, {'type': 'EngineTypeEnum', 'cardinality': '1..1',
                                'description': 'Type of engine'})

    def test_metadata_scheme(self):
        attr = self.model['types']['DrivingLicence']['attributes']['countryOfIssuance']
        self.assertEqual(attr['metadata'], {'scheme': True})

    def test_extends(self):
        self.assertEqual(self.model['types']['ElectricCar']['extends'], 'VehicleBase')

    def test_choice_options(self):
        self.assertEqual(self.model['choices']['Vehicle']['options'],
                         ['ElectricCar', 'CombustibleVehicle', 'Bicycle'])

    def test_function_condition_expression_verbatim(self):
        cond = self.model['functions']['Create_VehicleOwnership']['conditions']
        self.assertEqual(cond['DrivingLicenceExpiry'],
                         'drivingLicence -> dateOfRenewal all > dateOfPurchase')

    def test_misindented_func_recovered(self):
        # ' func Create_Bicycle:' has a leading space in the source
        self.assertIn('Create_Bicycle',
                      self.out['demo.emissions.ingestion']['functions'])


class CdmCorpus(unittest.TestCase):
    """Whole-corpus invariants over examples/cdm (145 files, 90 namespaces)."""

    @classmethod
    def setUpClass(cls):
        cls.out = convert_dir(CDM)

    def counts(self, kind):
        return sum(len(d.get(kind, {})) for d in self.out.values())

    # cdmLOG's CDM 8.0.0-dev copy (90 namespaces); here the corpus is DRR
    # 7.14.0 with its CDM 6.29 unless CDM_VERSION=8 says otherwise
    cdm8 = unittest.skipUnless(os.environ.get('CDM_VERSION') == '8', "figures of cdmLOG's CDM 8 copy")

    @cdm8
    def test_full_coverage(self):
        self.assertEqual(len(self.out), 90)

    @unittest.skipIf(os.environ.get('CDM_VERSION') == '8', 'figures of DRR 7.14.0')
    def test_drr_reads_whole(self):
        # DRR 7.14.0 (README.md of migration/rune, step 1)
        self.assertEqual(len(self.out), 327)
        self.assertEqual(self.counts('types'), 4191)
        self.assertEqual(self.counts('functions'), 2762)

    @cdm8
    def test_component_counts_match_source(self):
        # grep-derived counts over the .rosetta corpus
        self.assertEqual(self.counts('types'), 761)
        self.assertEqual(self.counts('enums'), 279)
        self.assertEqual(self.counts('functions'), 1312)
        self.assertEqual(self.counts('choices'), 16)
        self.assertEqual(self.counts('typeAliases'), 17)

    @cdm8
    def test_override_attribute(self):
        pos = self.out['cdm.event.position']['types']['Position']
        self.assertEqual(pos['attributes']['product']['cardinality'], '1..1')
        self.assertTrue(pos['attributes']['product']['override'])

    def test_attribute_named_condition(self):
        t = self.out['cdm.observable.asset']['types']['MultipleCreditNotations']
        self.assertEqual(t['attributes']['condition']['type'], 'QuantifierEnum')

    def test_anonymous_condition(self):
        t = self.out['cdm.base.staticdata.party']['types']['AncillaryEntity']
        self.assertEqual(t['conditions'], {'condition': 'one-of'})

    def test_dispatch_function_inherits_signature(self):
        fns = self.out['cdm.base.datetime.daycount']['functions']
        self.assertIn('YearFraction(ACT_360)', fns)
        self.assertIn('output', fns['YearFraction(ACT_360)'])
        self.assertEqual(fns['YearFraction(ACT_360)']['inputs'].keys(),
                         fns['YearFraction']['inputs'].keys())

    def test_choice_option_annotations_kept_separate(self):
        c = self.out['cdm.observable.asset']['choices']['Index']
        self.assertNotIn('[metadata location]', c['options'])
        self.assertIn('InterestRateIndex', c['optionAnnotations'])

    def test_corrupt_enum_regression(self):
        # the LLM-made file exploded docstrings into 237 bogus values
        vals = self.out['cdm.base.datetime']['enums'][
            'CommodityBusinessCalendarEnum']['values']
        self.assertEqual(len(vals), 115)

    def test_multiline_doc_reference(self):
        payer = self.out['cdm.base.staticdata.party']['types'][
            'PayerReceiver']['attributes']['payer']
        refs = payer['annotations']['docReference']
        self.assertEqual(refs[0]['source'], 'ICMA GMRA')
        self.assertEqual(refs[0]['namingConvention'], 'Seller')
        self.assertIn('paragraph 1(a)', refs[0]['provision'])

    def test_type_level_metadata_key(self):
        t = self.out['cdm.base.staticdata.party']['types']['Account']
        self.assertEqual(t['metadata'], {'key': True})

    def test_swapped_attribute_regression(self):
        # the LLM-made file emitted "calculation": {"type": "callFunction"}
        t = self.out['cdm.product.common.settlement']['types']['ComputedAmount']
        self.assertEqual(t['attributes']['callFunction']['type'], 'calculation')

    def test_isproduct_root(self):
        self.assertEqual(
            self.out['cdm.product.qualification']['rootDeclarations'],
            {'isProduct': 'EconomicTerms'})

    def test_enum_displayname(self):
        vals = self.out['cdm.base.datetime.daycount']['enums'][
            'DayCountFractionEnum']['values']
        by = {v['value']: v for v in vals if isinstance(v, dict)}
        self.assertEqual(by['ACT_360']['displayName'], 'ACT/360')


REPORTING = """namespace demo.reporting
version "1.0"

import demo.standards.* as std

corpus Regulation "Part 45" Part45

report CFTC Part45 in T+1
    from Instruction
    when IsReportable
    with type Part45Report

eligibility rule IsReportable from Instruction: <"When eligible">
    [docReference CFTC Part45 section "45.3(b)"
        provision "For each off-facility swap,
the reporting counterparty shall report."]
    filter True

reporting rule Cleared from Instruction: <"Cleared">
    [docReference ISDA PeerReviewGroup date "20220520"
        provision "The logic does not distinguish."]
    filter IsAllowable
    then extract std.Cleared // the standard's rule

type Part45Report:
    cleared string (1..1)
        [label "01 Cleared"]
        [ruleReference Cleared]
    leg1 Leg (0..1)
        [label for notional "1.1 Notional"]
        [ruleReference for notional NotionalLeg1]
        [docReference for notional CFTC Part45 field "Notional"
            provision "The notional."]
"""


class Reporting(unittest.TestCase):
    """report, reporting rule, eligibility rule (DRR), and import aliases."""

    @classmethod
    def setUpClass(cls):
        src = Path(tempfile.mkdtemp(prefix='r2j-rep-'))
        (src / 'demo.rosetta').write_text(REPORTING)
        cls.ns = convert_dir(src)['demo.reporting']

    def test_report(self):
        self.assertEqual(self.ns['reports']['CFTC Part45'], {
            'regulatoryBody': 'CFTC', 'corpus': ['Part45'], 'timing': 'T+1',
            'input': 'Instruction', 'eligibility': ['IsReportable'],
            'reportType': 'Part45Report'})

    def test_eligibility_rule(self):
        r = self.ns['eligibilityRules']['IsReportable']
        self.assertEqual(r['input'], 'Instruction')
        self.assertEqual(r['expression'], 'filter True')
        # a provision line at column 0 stays inside the provision
        self.assertIn('the reporting counterparty', r['annotations']['docReference'][0]['provision'])

    def test_reporting_rule(self):
        r = self.ns['reportingRules']['Cleared']
        self.assertEqual(r['description'], 'Cleared')
        self.assertEqual(r['expression'], 'filter IsAllowable\n    then extract std.Cleared')
        self.assertEqual(r['annotations']['docReference'][0]['source'], 'ISDA PeerReviewGroup')

    def test_rule_references_and_labels(self):
        attrs = self.ns['types']['Part45Report']['attributes']
        self.assertEqual(attrs['cleared']['annotations']['ruleReference'], [{'value': 'Cleared'}])
        self.assertEqual(attrs['cleared']['annotations']['label'], [{'value': '01 Cleared'}])
        leg = attrs['leg1']['annotations']
        self.assertEqual(leg['ruleReference'], [{'for': 'notional', 'value': 'NotionalLeg1'}])
        self.assertEqual(leg['docReference'][0]['for'], 'notional')
        self.assertEqual(leg['docReference'][0]['source'], 'CFTC Part45')

    def test_import_alias(self):
        self.assertEqual(self.ns['importAliases'], {'std': 'demo.standards'})
        self.assertEqual(self.ns['fileScopes']['demo.rosetta']['importAliases'],
                         {'std': 'demo.standards'})


if __name__ == '__main__':
    unittest.main(verbosity=2)
