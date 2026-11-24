#!/usr/bin/env python3
"""Test cases for Oracle's "Do I need to file" decision service.

The decision service has no test cases. Its expected outcomes here are those
of the United States Internal Revenue Service's filing requirements for tax
year 2022 (Publication 501, table 1, filers under 65: Single 12,950; Married
filing jointly 25,900; Married filing separately 5; Head of household 19,400)
and its "other situations" (an HSA or Archer MSA distribution, recapture
taxes, estimated tax payments, the additional child tax credit) — the rules
the decision service encodes — computed by this script, independently of the
Logical English twin. python3 make_tests.py > tests.json
"""
import json
THRESHOLD = {"Single": 12950, "Married filing jointly": 25900,
             "Married filing separately": 5, "Head of household": 19400}

def needs_to_file(c):
    st = c["filing_status"]
    income = c.get("gross_income")
    if st == "Married filing jointly":
        income = (c.get("gross_income") + c.get("spouses_gross_income")
                  if "gross_income" in c and "spouses_gross_income" in c else None)
    exceeds = income is not None and income > THRESHOLD[st]
    special = c.get("medical_savings_distributions") or c.get("recapture_taxes_owed")
    situations = c.get("estimated_tax_payments_made") or c.get("additional_child_credit")
    return bool(exceeds or special or situations)

cases = [
  ("single_above", "Single, 13,000 of gross income: above the 12,950 threshold.", {"filing_status": "Single", "gross_income": 13000}),
  ("single_below", "Single, 12,000: below the threshold, no other situation.", {"filing_status": "Single", "gross_income": 12000}),
  ("single_at_threshold", "Single, exactly 12,950: the threshold must be exceeded, not met.", {"filing_status": "Single", "gross_income": 12950}),
  ("joint_household_above", "Married filing jointly, 15,000 + 11,000 = 26,000: above 25,900.", {"filing_status": "Married filing jointly", "gross_income": 15000, "spouses_gross_income": 11000}),
  ("joint_household_below", "Married filing jointly, 15,000 + 10,000 = 25,000: below 25,900.", {"filing_status": "Married filing jointly", "gross_income": 15000, "spouses_gross_income": 10000}),
  ("separately_any_income", "Married filing separately, 6 of income: the threshold is 5.", {"filing_status": "Married filing separately", "gross_income": 6}),
  ("head_of_household_below", "Head of household, 19,000: below 19,400.", {"filing_status": "Head of household", "gross_income": 19000}),
  ("head_of_household_above", "Head of household, 20,000: above 19,400.", {"filing_status": "Head of household", "gross_income": 20000}),
  ("hsa_distribution", "Below the threshold, but a distribution from a medical savings account: must file.", {"filing_status": "Single", "gross_income": 5000, "medical_savings_distributions": True}),
  ("recapture_taxes", "No income stated, recapture taxes owed: must file.", {"filing_status": "Head of household", "recapture_taxes_owed": True}),
  ("estimated_payments", "Below the threshold, estimated tax payments made: must file.", {"filing_status": "Single", "gross_income": 1000, "estimated_tax_payments_made": True}),
  ("child_tax_credit", "Below the threshold, claiming the additional child tax credit: must file.", {"filing_status": "Head of household", "gross_income": 9000, "additional_child_credit": True}),
]
out = {"source": "IRS filing requirements for tax year 2022 (Publication 501), as the decision service encodes them; expected outcomes computed by make_tests.py.",
       "cases": [{"id": i, "description": d, "inputs": c, "expected": {"tax_return_needed": needs_to_file(c)}} for i, d, c in cases]}
print(json.dumps(out, indent=1))
