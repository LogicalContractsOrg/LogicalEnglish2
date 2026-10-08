# Migration ledger: us_statutes_7_2014_e_2_b

Source: Axiom RuleSpec — sources/us/statutes/7/2014/e/2/B.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-07
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 0 |
| **total** | 1 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2014/e/2/B#snap_earned_income_deduction_rate | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_earned_income_deduction_rate |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| earned_income_deduction_rate_is_twenty_percent | q_snap_earned_income_deduction_rate | pass |  |

