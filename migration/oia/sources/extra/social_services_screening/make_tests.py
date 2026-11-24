#!/usr/bin/env python3
"""Expected values for the reconstructed Social Services Screening rules
(README.md), computed by this Python model of them, independently of the
twin. python3 make_tests.py > tests.json"""
import json
TABLE = {1: 1580, 2: 2137, 3: 2694, 4: 3250}

def model(c):
    ms = c.get("members", [])
    size = len(ms)
    income = sum(m.get("member_income", 0) for m in ms)
    limit = TABLE.get(size, 3250 + (557 * (size - 4)))
    child = lambda m: m["member_age"] < 13
    avail = lambda m: child(m) or m.get("member_employed", False) or m.get("member_student", False)
    vuln = sum(1 for m in ms if m["member_age"] >= 60 or m.get("member_disability", False))
    energy = vuln > 0 and income <= limit * 1.5
    return {"household_size": size, "household_income": income, "income_limit": limit,
            "food_assistance": income <= limit and c["countable_assets"] < 2750,
            "child_care_assistance": any(child(m) for m in ms) and all(avail(m) for m in ms) and income <= limit * 1.5,
            "vulnerable_members": vuln, "energy_assistance": energy,
            "energy_credit": 150 if energy and vuln >= 2 else 100 if energy else 0}

def members(*xs):
    return [dict({"@id": "m%d" % i}, **x) for i, x in enumerate(xs, 1)]

cases = [
  ("single_parent_working", "A working single parent with two young children, 2,400 a month: food (limit 2,694 for three) and child care assistance.",
   {"countable_assets": 900, "members": members({"member_age": 34, "member_income": 2400, "member_employed": True}, {"member_age": 6}, {"member_age": 3})}),
  ("parent_not_available", "Two parents, one neither employed nor studying: no child care assistance (not every member available).",
   {"countable_assets": 1500, "members": members({"member_age": 38, "member_income": 3000, "member_employed": True}, {"member_age": 36}, {"member_age": 9})}),
  ("pensioner_couple", "Two pensioners over 60, 1,900 a month: food assistance (limit 2,137), energy credit 150 (two vulnerable members).",
   {"countable_assets": 2000, "members": members({"member_age": 71, "member_income": 1100}, {"member_age": 68, "member_income": 800})}),
  ("assets_too_high", "One person, 1,200 a month but 5,000 of countable assets: no food assistance; disabled: energy credit 100.",
   {"countable_assets": 5000, "members": members({"member_age": 45, "member_income": 1200, "member_disability": True})}),
  ("large_household_formula", "Six members: the limit is 3,250 + 557 x 2 = 4,364; 4,300 of income qualifies for food assistance; a student and a worker with four children: child care too.",
   {"countable_assets": 100, "members": members({"member_age": 40, "member_income": 3500, "member_employed": True},
                                               {"member_age": 19, "member_income": 800, "member_student": True},
                                               {"member_age": 12}, {"member_age": 10}, {"member_age": 7}, {"member_age": 1})}),
  ("income_above_one_and_a_half", "Two members with 3,300 a month (above 1.5 x 2,137 = 3,205.5): no assistance of any kind.",
   {"countable_assets": 100, "members": members({"member_age": 62, "member_income": 3300}, {"member_age": 4})}),
]
out = {"source": "Synthetic cases for the reconstructed Social Services Screening rules; expected values computed by make_tests.py.",
       "cases": [{"id": i, "description": d, "inputs": c, "expected": model(c)} for i, d, c in cases]}
print(json.dumps(out, indent=1))
