# Migration ledger: 0010_multi_output_u

Source: DMN — 0010-multi-output-U.dmn
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
| Approval | decision table | approximated | decision table | Approval | a column that compares numbers and has `-` cells: where its input is null the table has no answer, while DMN matches a row with `-` |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| t001 | q_d_status_of_the_approval | pass |  |
| t001 | q_d_rate_of_the_approval | pass |  |
| t002 | q_d_status_of_the_approval | pass |  |
| t002 | q_d_rate_of_the_approval | pass |  |
| t003 | q_d_status_of_the_approval | pass |  |
| t003 | q_d_rate_of_the_approval | pass |  |

