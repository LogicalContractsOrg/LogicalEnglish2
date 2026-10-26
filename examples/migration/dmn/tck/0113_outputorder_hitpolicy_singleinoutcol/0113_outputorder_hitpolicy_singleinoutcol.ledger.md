# Migration ledger: 0113_outputorder_hitpolicy_singleinoutcol

Source: DMN — 0113-outputOrder-hitpolicy-singleinoutcol.dmn
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
| Approval Status | decision table | encoded | decision table | Approval Status |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| t001 | q_d_rel_approval_status | pass |  |
| t002 | q_d_rel_approval_status | pass |  |
| t003 | q_d_rel_approval_status | pass |  |

