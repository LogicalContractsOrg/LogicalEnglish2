# Migration ledger: us_statutes_7_2014_e_2

Source: Axiom RuleSpec — sources/us/statutes/7/2014/e/2/B.yaml, sources/us/statutes/7/2014/e/2.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-06
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 5 |
| approximated | 0 |
| residue | 0 |
| **total** | 5 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2014/e/2/B#snap_earned_income_deduction_rate | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_earned_income_deduction_rate |  |
| us:statutes/7/2014/e/2#snap_earned_income_subject_to_deduction | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_earned_income_subject_to_deduction |  |
| us:statutes/7/2014/e/2#snap_earned_income_deduction | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_earned_income_deduction |  |
| input snap_countable_earned_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_countable_earned_income |  |
| input work_supplementation_earned_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_work_supplementation_earned_income |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| earned_income_deduction_is_twenty_percent | q_snap_earned_income_deduction | pass |  |
| earned_income_deduction_is_twenty_percent | q_snap_earned_income_subject_to_deduction | pass |  |
| work_supplementation_income_is_excluded | q_snap_earned_income_deduction | pass |  |
| work_supplementation_income_is_excluded | q_snap_earned_income_subject_to_deduction | pass |  |

