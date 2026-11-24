#!/usr/bin/env python3
"""Expected values for the reconstructed Aged Care Approval rules (README.md),
computed by this Python model of them, independently of the twin.
python3 make_tests.py > tests.json"""
import json, datetime, calendar
D = datetime.date.fromisoformat

def add_months(d, n):
    y, m = divmod(d.month - 1 + n, 12); y += d.year; m += 1
    return datetime.date(y, m, min(d.day, calendar.monthrange(y, m)[1]))

def years_between(a, b):
    return b.year - a.year - ((b.month, b.day) < (a.month, a.day))

def model(c):
    out = {}
    age = years_between(D(c["date_of_birth"]), D(c["assessment_date"]))
    out["age_at_assessment"] = age
    eligible = age >= 65 or (age >= 50 and c.get("aboriginal", False)) or c.get("care_need", False)
    ad, asd = D(c["approval_date"]), D(c["assessment_date"])
    in_time = ad >= asd and (ad - asd).days <= 30
    limited = c["approval_type"] in ("Residential respite care", "Short-term restorative care")
    now = D(c["current_date"])
    lapsed = False
    if limited:
        end = add_months(ad, 12)
        out["approval_end_date"] = end.isoformat()
        entered = "entry_date" in c and D(c["entry_date"]) <= end
        lapsed = now > end and not entered
        if now <= end:
            out["days_until_end"] = (end - now).days
    out["approval_valid"] = bool(eligible and in_time and not lapsed and not c.get("revoked", False))
    if c["approval_type"] == "Residential respite care":
        used = sum((D(s["stay_end"]) - D(s["stay_start"])).days + 1 for s in c.get("respite_stays", []))
        out["respite_days_remaining"] = max(63 - used, 0)
    return out

def stays(*xs):
    return [dict({"@id": "stay%d" % i}, stay_start=a, stay_end=b) for i, (a, b) in enumerate(xs, 1)]

cases = [
  ("permanent_care_valid", "Aged 77 at assessment, permanent residential care approved 12 days later: valid, with no end date.",
   {"date_of_birth": "1948-05-02", "assessment_date": "2026-03-01", "approval_date": "2026-03-13", "approval_type": "Permanent residential care", "current_date": "2026-10-15"}),
  ("approval_too_late", "Approved 45 days after the assessment: not made in time, not valid.",
   {"date_of_birth": "1950-01-01", "assessment_date": "2026-01-10", "approval_date": "2026-02-24", "approval_type": "Home care", "current_date": "2026-10-15"}),
  ("respite_lapsed", "A respite approval of 31 March 2025, no entry into care, asked on 15 October 2026: lapsed on 31 March 2026.",
   {"date_of_birth": "1945-07-07", "assessment_date": "2025-03-20", "approval_date": "2025-03-31", "approval_type": "Residential respite care", "current_date": "2026-10-15"}),
  ("respite_entered_in_time", "The same approval, care entered on 1 March 2026 (before it ended): not lapsed, valid.",
   {"date_of_birth": "1945-07-07", "assessment_date": "2025-03-20", "approval_date": "2025-03-31", "approval_type": "Residential respite care", "current_date": "2026-10-15", "entry_date": "2026-03-01"}),
  ("respite_days_remaining", "A current respite approval, two stays of 14 and 21 days taken: 28 of the 63 days remain; 135 days until the approval ends.",
   {"date_of_birth": "1940-12-31", "assessment_date": "2026-02-20", "approval_date": "2026-02-27", "approval_type": "Residential respite care", "current_date": "2026-10-15",
    "respite_stays": stays(("2026-04-01", "2026-04-14"), ("2026-06-10", "2026-06-30"))}),
  ("younger_aboriginal_person", "Aged 54 at assessment, an Aboriginal person: eligible; short-term restorative care approved on 28 February 2026 ends twelve months later, on 28 February 2027 (136 days away).",
   {"date_of_birth": "1971-06-15", "assessment_date": "2026-02-01", "approval_date": "2026-02-28", "approval_type": "Short-term restorative care", "current_date": "2026-10-15", "aboriginal": True}),
  ("younger_without_need", "Aged 52, no care need stated, not Aboriginal or Torres Strait Islander: not eligible.",
   {"date_of_birth": "1974-03-03", "assessment_date": "2026-05-05", "approval_date": "2026-05-06", "approval_type": "Home care", "current_date": "2026-10-15"}),
  ("revoked", "Valid in every way, but revoked.",
   {"date_of_birth": "1939-09-09", "assessment_date": "2026-01-05", "approval_date": "2026-01-06", "approval_type": "Home care", "current_date": "2026-10-15", "revoked": True}),
]
out = {"source": "Synthetic cases for the reconstructed Aged Care Approval rules; expected values computed by make_tests.py.",
       "cases": [{"id": i, "description": d, "inputs": c, "expected": model(c)} for i, d, c in cases]}
print(json.dumps(out, indent=1))
