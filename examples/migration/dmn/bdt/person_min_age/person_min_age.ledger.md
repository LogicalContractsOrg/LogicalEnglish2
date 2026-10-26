# Migration ledger: person_min_age

Source: DMN — person-min-age.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 0 |
| **total** | 1 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| checkResult | context | encoded | context | checkResult |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Empty | q_d_check_result | pass |  |
| Person_At_Min_Age | q_d_check_result | pass |  |
| Person_with_Null_DOB | q_d_check_result | pass |  |

