# Migration ledger: replacement_tree_decision

Source: DMN — replacement-tree-decision.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 0 |
| **total** | 1 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Replacement Tree Required? | decision table | encoded | decision table | Replacement Tree Required? |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| g001 | q_d_replacement_tree_required | pass |  |
| g002 | q_d_replacement_tree_required | pass |  |

