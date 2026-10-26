# Migration ledger: 0117_multi_any_hitpolicy

Source: DMN — 0117-multi-any-hitpolicy.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 0 |
| approximated | 1 |
| residue | 0 |
| **total** | 1 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Approval | decision table | approximated | decision table | Approval | ANY: the first matching row answers; DMN also reports an error when the matching rows disagree |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| t001 | q_d_status_of_the_approval | pass |  |
| t001 | q_d_rate_of_the_approval | pass |  |
| t002 | q_d_status_of_the_approval | pass |  |
| t002 | q_d_rate_of_the_approval | pass |  |
| t003 | q_d_status_of_the_approval | pass |  |
| t003 | q_d_rate_of_the_approval | pass |  |

