# Migration ledger: 5_1_modular_node_two_paths

Source: RUML — modular-node-two-paths.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 3 |
| approximated | 1 |
| residue | 0 |
| **total** | 4 |

Fidelity: **24 of 24** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| node(1) | AND | encoded | AND of 2 children | Kreditvergabe holds for *a case* | label: Kreditvergabe |
| node(8) | leaf | encoded | a leaf with no deciding capability: a person's answer, a fact of the case (`the answer to ... is true`) | Bonitätsprüfung holds for *a case* | label: Bonitätsprüfung; RUML: undefined until answered |
| node(2) | AND | encoded | AND of 1 children | Alternative Prüfungen holds for *a case* | label: Alternative Prüfungen |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |
| generated_1 | node_2 | pass |  |
| generated_1 | not_node_2 | pass |  |
| generated_1 | node_8 | pass |  |
| generated_1 | not_node_8 | pass |  |
| generated_2 | node_1 | pass |  |
| generated_2 | not_node_1 | pass |  |
| generated_2 | node_2 | pass |  |
| generated_2 | not_node_2 | pass |  |
| generated_2 | node_8 | pass |  |
| generated_2 | not_node_8 | pass |  |
| generated_3 | node_1 | pass |  |
| generated_3 | not_node_1 | pass |  |
| generated_3 | node_2 | pass |  |
| generated_3 | not_node_2 | pass |  |
| generated_3 | node_8 | pass |  |
| generated_3 | not_node_8 | pass |  |
| generated_4 | node_1 | pass |  |
| generated_4 | not_node_1 | pass |  |
| generated_4 | node_2 | pass |  |
| generated_4 | not_node_2 | pass |  |
| generated_4 | node_8 | pass |  |
| generated_4 | not_node_8 | pass |  |

