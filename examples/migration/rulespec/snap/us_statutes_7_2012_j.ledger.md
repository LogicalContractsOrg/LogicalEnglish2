# Migration ledger: us_statutes_7_2012_j

Source: Axiom RuleSpec — sources/us/statutes/7/2012/j.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-07
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 3 |
| approximated | 0 |
| residue | 0 |
| **total** | 3 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2012/j#member_of_household | data_relation | encoded | data relation -> a two-place sentence the scenario states | rs_member_of_household |  |
| us:statutes/7/2012/j#snap_household_has_elderly_or_disabled_member | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_snap_household_has_elderly_or_disabled_member |  |
| input snap_member_is_elderly_or_disabled | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_member_is_elderly_or_disabled |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| household_has_elderly_or_disabled_member | q_snap_household_has_elderly_or_disabled_member | pass |  |
| household_without_elderly_or_disabled_member | q_snap_household_has_elderly_or_disabled_member | pass |  |

