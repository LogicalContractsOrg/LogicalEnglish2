# Migration ledger: tree_felling_decision

Source: DMN — tree-felling-decision.dmn
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
| Tree Felling Permitted? | decision table | encoded | decision table | Tree Felling Permitted? |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| g001 | q_d_tree_felling_permitted | pass |  |
| g002 | q_d_tree_felling_permitted | pass |  |
| g003 | q_d_tree_felling_permitted | pass |  |
| g004 | q_d_tree_felling_permitted | pass |  |

