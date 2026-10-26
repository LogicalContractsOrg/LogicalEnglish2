# Migration ledger: 0116_count_collect_hitpolicy

Source: DMN — 0116-count-collect-hitpolicy.dmn
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
| Salary | decision table | encoded | decision table | Salary |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| t001 | q_d_salary | pass |  |
| t002 | q_d_salary | pass |  |
| t003 | q_d_salary | pass |  |

