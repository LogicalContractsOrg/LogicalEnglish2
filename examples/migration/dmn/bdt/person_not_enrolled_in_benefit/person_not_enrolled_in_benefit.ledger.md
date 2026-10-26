# Migration ledger: person_not_enrolled_in_benefit

Source: DMN — person-not-enrolled-in-benefit.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 0 |
| **total** | 1 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| checkResult | literal expression | encoded | literal expression | checkResult |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Enrolled | q_d_check_result | pass |  |
| Enrollments_empty | q_d_check_result | pass |  |
| Enrollments_null | q_d_check_result | pass |  |
| NOT_Enrolled_in_Bogus_Benefit | q_d_check_result | pass |  |

