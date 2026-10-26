# Migration ledger: 0005_simpletable_a

Source: DMN — 0005-simpletable-A.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 0 |
| approximated | 1 |
| residue | 0 |
| **total** | 1 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Approval Status | decision table | approximated | decision table | Approval Status | ANY: the first matching row answers; DMN also reports an error when the matching rows disagree |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| t001 | q_d_approval_status | pass |  |
| t002 | q_d_approval_status | pass |  |
| t003 | q_d_approval_status | pass |  |

