# Migration ledger: property_assessment_increase

Source: DMN — property-assessment-increase.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 0 |
| **total** | 1 |

Fidelity: **7 of 7** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| checkResult | context | encoded | context | checkResult |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Fail | q_d_check_result | pass |  |
| Five_year_only | q_d_check_result | pass |  |
| Five_year_path | q_d_check_result | pass |  |
| Null | q_d_check_result | pass |  |
| Pass | q_d_check_result | pass |  |
| Unknown_five_year_history | q_d_check_result | pass |  |
| Zero_baseline | q_d_check_result | pass |  |

