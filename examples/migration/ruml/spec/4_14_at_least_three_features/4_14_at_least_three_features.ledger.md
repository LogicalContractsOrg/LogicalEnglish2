# Migration ledger: 4_14_at_least_three_features

Source: RUML — at-least-three-features.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 7 |
| approximated | 1 |
| residue | 0 |
| **total** | 8 |

Fidelity: **14 of 14** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| node(1) | AND | encoded | AND of 1 children | Anspruch besteht holds for *a case* |  |
| node(2) | DELEGATED | encoded | DELEGATED: $count($children[status = 'true']) >= 3 | Mindestens drei Merkmale erfüllt holds for *a case* | exact: undefined whenever a child is undefined, as the combiner contract says (§3.6.4) |
| node(3) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Merkmal 1 holds for *a case* | RUML: undefined until decided |
| node(4) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Merkmal 2 holds for *a case* | RUML: undefined until decided |
| node(5) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Merkmal 3 holds for *a case* | RUML: undefined until decided |
| node(6) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Merkmal 4 holds for *a case* | RUML: undefined until decided |
| node(7) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Merkmal 5 holds for *a case* | RUML: undefined until decided |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |
| generated_1 | node_2 | pass |  |
| generated_1 | not_node_2 | pass |  |
| generated_1 | node_3 | pass |  |
| generated_1 | not_node_3 | pass |  |
| generated_1 | node_4 | pass |  |
| generated_1 | not_node_4 | pass |  |
| generated_1 | node_5 | pass |  |
| generated_1 | not_node_5 | pass |  |
| generated_1 | node_6 | pass |  |
| generated_1 | not_node_6 | pass |  |
| generated_1 | node_7 | pass |  |
| generated_1 | not_node_7 | pass |  |

