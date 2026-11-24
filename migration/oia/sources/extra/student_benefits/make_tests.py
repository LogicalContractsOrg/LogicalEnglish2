#!/usr/bin/env python3
"""Test cases for Oracle's "Student Benefits" flow project.

The flow ships with no test cases. These follow the United States Federal
Student Aid basic eligibility criteria the project's rules encode (financial
need against the family-size income table, citizenship or eligible
non-citizen status, a Social Security number or the Freely Associated States
exception, enrolment, academic progress, a high school credential, the two
signed declarations), computed by this Python model of the rules,
independently of the Logical English twin. python3 make_tests.py > tests.json
"""
import json, datetime
TABLE = {1: 22340, 2: 30260, 3: 38180, 4: 46100, 5: 54020, 6: 61940, 7: 69860, 8: 77780}
I94 = "the designation on the student's Arrival-Departure Record _I-94_ from US Citizenship and Immigration Services _USCIS_"
I94DATE = "the issue date of the student's Arrival-Departure Record _I-94_ from US Citizenship and Immigration Services _USCIS_"
HAS_I94 = "the student has an Arrival-Departure Record _I-94_ from US Citizenship and Immigration Services _USCIS_"

def threshold(n):
    return TABLE[n] if n in TABLE else 77780 + (7920 * (n - 8))

def eligible(c):
    g = c.get
    need = g("the student's annual family income") < threshold(g("the number of people in the student's family"))
    status = g("the student's citizenship/immigration status")
    citizen = status == "citizen"
    d = g(I94); date = g(I94DATE)
    non_citizen = status in ("national", "permanent resident") or (g(HAS_I94, False) and (
        d in ("Refugee", "Asylum Grant", "Cuban-Haitian Entrant _Status Pending_",
              "Victim of human trafficking, T-visa _T-2, T-3, T-4_")
        or (d == "Conditional Entrant" and date is not None and date < "1980-04-01")
        or (d == "Parolee" and g("the student is paroled into the US for at least one year", False)
            and g("the student is able to provide evidence from the USCIS that the student is in the US for other than a temporary purpose", False)
            and g("the student intends to become a US citizen or permanent resident", False))))
    ssn = g("the student has a valid Social Security Number", False) or any(g(x, False) for x in (
        "the student is from the Republic of the Marshall Islands", "the student is from the Federated States of Micronesia",
        "the student is from the Republic of Palau"))
    enrol = g("the student's enrollment status") in ("enrolled", "accepted")
    education = enrol and g("the student has maintained satisfactory academic progress in college or career school", False) and (
        g("the student has a high school diploma", False) or g("the student has a General Educational Development _GED_ certificate", False)
        or g("the student has completed a high school education in a state-approved home school setting", False))
    declarations = g("the student has signed a declaration that the student is not in default on a federal student loan", False) and \
        g("the student has signed a declaration that the student will use the federal student aid for educational purposes only", False)
    return bool(need and (citizen or non_citizen) and ssn and education and declarations)

base = {"the student's annual family income": 40000, "the number of people in the student's family": 4,
        "the student's citizenship/immigration status": "citizen", "the student's enrollment status": "enrolled",
        "the student has maintained satisfactory academic progress in college or career school": True,
        "the student has a high school diploma": True, "the student has a valid Social Security Number": True,
        "the student has signed a declaration that the student is not in default on a federal student loan": True,
        "the student has signed a declaration that the student will use the federal student aid for educational purposes only": True}
cases = [
  ("citizen_eligible", "A US citizen in a family of 4 with 40,000 of income (threshold 46,100), meeting every criterion.", {}),
  ("income_too_high", "The same student with 50,000 of family income: above the threshold of 46,100.", {"the student's annual family income": 50000}),
  ("large_family", "A family of 10 with 90,000: the threshold is 77,780 + 7,920 x 2 = 93,620.", {"the number of people in the student's family": 10, "the student's annual family income": 90000}),
  ("refugee", "A refugee with an I-94 record: an eligible non-citizen.", {"the student's citizenship/immigration status": "other", HAS_I94: True, I94: "Refugee"}),
  ("conditional_entrant_before_1980", "A conditional entrant whose I-94 was issued in December 1979: eligible.", {"the student's citizenship/immigration status": "other", HAS_I94: True, I94: "Conditional Entrant", I94DATE: "1979-12-01"}),
  ("conditional_entrant_after_1980", "A conditional entrant whose I-94 was issued in 1981: not eligible.", {"the student's citizenship/immigration status": "other", HAS_I94: True, I94: "Conditional Entrant", I94DATE: "1981-06-15"}),
  ("palau_without_ssn", "A student from the Republic of Palau without a Social Security number: the exception applies.", {"the student has a valid Social Security Number": False, "the student is from the Republic of Palau": True}),
  ("no_ssn", "No Social Security number and no exception: not eligible.", {"the student has a valid Social Security Number": False}),
  ("one_declaration_missing", "Only one of the two declarations signed: not eligible.", {"the student has signed a declaration that the student will use the federal student aid for educational purposes only": False}),
  ("accepted_with_ged", "Accepted for enrolment, with a GED certificate instead of a diploma: eligible.", {"the student's enrollment status": "accepted", "the student has a high school diploma": False, "the student has a General Educational Development _GED_ certificate": True}),
  ("parolee_intending_citizenship", "A parolee for at least a year, with USCIS evidence, intending to become a citizen: eligible.", {"the student's citizenship/immigration status": "other", HAS_I94: True, I94: "Parolee", "the student is paroled into the US for at least one year": True, "the student is able to provide evidence from the USCIS that the student is in the US for other than a temporary purpose": True, "the student intends to become a US citizen or permanent resident": True}),
]
out = {"source": "US Federal Student Aid basic eligibility criteria as the project's rules encode them; expected outcomes computed by make_tests.py.", "cases": []}
for cid, desc, delta in cases:
    c = dict(base); c.update(delta)
    out["cases"].append({"id": cid, "description": desc, "inputs": c,
        "expected": {"the student satisfies the basic eligibility requirements for student aid": eligible(c),
                     "the income threshold for the family size": threshold(c["the number of people in the student's family"])}})
print(json.dumps(out, indent=1))
