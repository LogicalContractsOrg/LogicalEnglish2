# Migration ledger: sctf_age_requirement

Source: DMN — sctf-age-requirement.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 0 |
| **total** | 1 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| checkResult | context | encoded | context | checkResult |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Fail | q_d_check_result | pass |  |
| Known_no_spouse | q_d_check_result | pass |  |
| Null_late_spouse_unknown | q_d_check_result | pass |  |
| Null | q_d_check_result | pass |  |
| Pass_late_spouse | q_d_check_result | pass |  |
| Pass | q_d_check_result | pass |  |

