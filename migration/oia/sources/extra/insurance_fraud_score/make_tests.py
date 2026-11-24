#!/usr/bin/env python3
"""Expected values for the reconstructed Insurance Fraud Score rules,
computed by this Python model of them (README.md), independently of the
twin. python3 make_tests.py > tests.json"""
import json, datetime
D = datetime.date.fromisoformat

def add_months(d, n):
    y, m = divmod(d.month - 1 + n, 12)
    y += d.year; m += 1
    import calendar
    return datetime.date(y, m, min(d.day, calendar.monthrange(y, m)[1]))

def model(c):
    prev = c.get("previous_claims", [])
    n = len(prev)
    claim_date = D(c["claim_date"])
    start12 = add_months(claim_date, -12)
    recent = sum(1 for p in prev if D(p["previous_claim_date"]) >= start12)
    rejected = any(p.get("previous_claim_rejected") for p in prev)
    out = {"recent_claims": recent}
    amount_score = 0
    if n > 0:
        avg = sum(p["previous_claim_amount"] for p in prev) / n
        out["average_previous_claim"] = round(avg, 2)
        ratio = c["claim_amount"] / avg
        amount_score = 40 if ratio >= 3 else 20 if ratio >= 1.5 else 0
    recency = min(15 * recent, 45)
    age = (claim_date - D(c["policy_start_date"])).days
    age_score = 30 if age < 30 else 10 if age < 90 else 0
    t = c["claim_type"]
    type_score = 25 if t == "Theft" and not c.get("reported_to_police") else 15 if t == "Theft" else 10 if t == "Fire" else 0
    rej_score = 20 if rejected else 0
    score = amount_score + recency + age_score + type_score + rej_score
    out.update({"fraud_score": score, "referred": score >= 50,
                "risk_band": "High" if score >= 70 else "Medium" if score >= 40 else "Low"})
    return out

def claims(*xs):
    return [dict({"@id": "pc%d" % i}, **x) for i, x in enumerate(xs, 1)]

cases = [
  ("first_claim_new_policy_theft", "A first claim, a theft not reported to the police, 20 days into the policy: 30 + 25 = 55, referred.",
   {"claim_amount": 4000, "claim_date": "2026-03-10", "policy_start_date": "2026-02-18", "claim_type": "Theft", "previous_claims": []}),
  ("large_claim_against_history", "A claim three times the average of two earlier claims, one of them in the last twelve months: 40 + 15 = 55.",
   {"claim_amount": 9000, "claim_date": "2026-05-01", "policy_start_date": "2019-01-01", "claim_type": "Accident", "reported_to_police": True,
    "previous_claims": claims({"previous_claim_amount": 2000, "previous_claim_date": "2025-09-15"},
                              {"previous_claim_amount": 4000, "previous_claim_date": "2023-02-01"})}),
  ("many_recent_claims_capped", "Four claims in the last year (recency capped at 45), one rejected (20), a fire (10): 75, High.",
   {"claim_amount": 1000, "claim_date": "2026-06-30", "policy_start_date": "2020-06-30", "claim_type": "Fire",
    "previous_claims": claims({"previous_claim_amount": 900, "previous_claim_date": "2026-01-10", "previous_claim_rejected": True},
                              {"previous_claim_amount": 1100, "previous_claim_date": "2025-12-01"},
                              {"previous_claim_amount": 800, "previous_claim_date": "2025-08-20"},
                              {"previous_claim_amount": 1200, "previous_claim_date": "2025-07-01"})}),
  ("twelve_month_boundary", "A previous claim exactly twelve months before (30 June 2025 for 30 June 2026) counts as recent.",
   {"claim_amount": 500, "claim_date": "2026-06-30", "policy_start_date": "2015-01-01", "claim_type": "Water damage",
    "previous_claims": claims({"previous_claim_amount": 600, "previous_claim_date": "2025-06-30"})}),
  ("reported_theft_medium", "A reported theft, 60 days into the policy, 1.5 times the earlier claim: 20 + 10 + 15 = 45, Medium, not referred.",
   {"claim_amount": 1500, "claim_date": "2026-04-01", "policy_start_date": "2026-01-31", "claim_type": "Theft", "reported_to_police": True,
    "previous_claims": claims({"previous_claim_amount": 1000, "previous_claim_date": "2024-11-11"})}),
  ("clean_low", "An old policy, an ordinary claim, no history: 0, Low.",
   {"claim_amount": 700, "claim_date": "2026-02-02", "policy_start_date": "2010-02-02", "claim_type": "Accident", "reported_to_police": True, "previous_claims": []}),
]
out = {"source": "Synthetic cases for the reconstructed Insurance Fraud Score rules; expected values computed by make_tests.py.",
       "cases": [{"id": i, "description": d, "inputs": c, "expected": model(c)} for i, d, c in cases]}
print(json.dumps(out, indent=1))
