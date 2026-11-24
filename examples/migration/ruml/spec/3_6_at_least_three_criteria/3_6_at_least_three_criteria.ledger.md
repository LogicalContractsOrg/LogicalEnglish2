# Migration ledger: 3_6_at_least_three_criteria

Source: RUML — at-least-three-criteria.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 6 |
| approximated | 1 |
| residue | 0 |
| **total** | 7 |

Fidelity: **96 of 96** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| node(1) | DELEGATED | encoded | DELEGATED: $count($children[status = 'true']) >= 3 | Mindestens drei Merkmale erfüllt holds for *a case* | label: Mindestens drei Merkmale erfüllt; exact: undefined whenever a child is undefined, as the combiner contract says (§3.6.4) |
| node(3) | leaf | encoded | a leaf with no deciding capability: a person's answer, a fact of the case (`the answer to ... is true`) | Merkmal 1 holds for *a case* | label: Merkmal 1; RUML: undefined until answered |
| node(4) | leaf | encoded | a leaf with no deciding capability: a person's answer, a fact of the case (`the answer to ... is true`) | Merkmal 2 holds for *a case* | label: Merkmal 2; RUML: undefined until answered |
| node(5) | leaf | encoded | a leaf with no deciding capability: a person's answer, a fact of the case (`the answer to ... is true`) | Merkmal 3 holds for *a case* | label: Merkmal 3; RUML: undefined until answered |
| node(6) | leaf | encoded | a leaf with no deciding capability: a person's answer, a fact of the case (`the answer to ... is true`) | Merkmal 4 holds for *a case* | label: Merkmal 4; RUML: undefined until answered |
| node(7) | leaf | encoded | a leaf with no deciding capability: a person's answer, a fact of the case (`the answer to ... is true`) | Merkmal 5 holds for *a case* | label: Merkmal 5; RUML: undefined until answered |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |
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
| generated_2 | node_1 | pass |  |
| generated_2 | not_node_1 | pass |  |
| generated_2 | node_3 | pass |  |
| generated_2 | not_node_3 | pass |  |
| generated_2 | node_4 | pass |  |
| generated_2 | not_node_4 | pass |  |
| generated_2 | node_5 | pass |  |
| generated_2 | not_node_5 | pass |  |
| generated_2 | node_6 | pass |  |
| generated_2 | not_node_6 | pass |  |
| generated_2 | node_7 | pass |  |
| generated_2 | not_node_7 | pass |  |
| generated_3 | node_1 | pass |  |
| generated_3 | not_node_1 | pass |  |
| generated_3 | node_3 | pass |  |
| generated_3 | not_node_3 | pass |  |
| generated_3 | node_4 | pass |  |
| generated_3 | not_node_4 | pass |  |
| generated_3 | node_5 | pass |  |
| generated_3 | not_node_5 | pass |  |
| generated_3 | node_6 | pass |  |
| generated_3 | not_node_6 | pass |  |
| generated_3 | node_7 | pass |  |
| generated_3 | not_node_7 | pass |  |
| generated_4 | node_1 | pass |  |
| generated_4 | not_node_1 | pass |  |
| generated_4 | node_3 | pass |  |
| generated_4 | not_node_3 | pass |  |
| generated_4 | node_4 | pass |  |
| generated_4 | not_node_4 | pass |  |
| generated_4 | node_5 | pass |  |
| generated_4 | not_node_5 | pass |  |
| generated_4 | node_6 | pass |  |
| generated_4 | not_node_6 | pass |  |
| generated_4 | node_7 | pass |  |
| generated_4 | not_node_7 | pass |  |
| generated_5 | node_1 | pass |  |
| generated_5 | not_node_1 | pass |  |
| generated_5 | node_3 | pass |  |
| generated_5 | not_node_3 | pass |  |
| generated_5 | node_4 | pass |  |
| generated_5 | not_node_4 | pass |  |
| generated_5 | node_5 | pass |  |
| generated_5 | not_node_5 | pass |  |
| generated_5 | node_6 | pass |  |
| generated_5 | not_node_6 | pass |  |
| generated_5 | node_7 | pass |  |
| generated_5 | not_node_7 | pass |  |
| generated_6 | node_1 | pass |  |
| generated_6 | not_node_1 | pass |  |
| generated_6 | node_3 | pass |  |
| generated_6 | not_node_3 | pass |  |
| generated_6 | node_4 | pass |  |
| generated_6 | not_node_4 | pass |  |
| generated_6 | node_5 | pass |  |
| generated_6 | not_node_5 | pass |  |
| generated_6 | node_6 | pass |  |
| generated_6 | not_node_6 | pass |  |
| generated_6 | node_7 | pass |  |
| generated_6 | not_node_7 | pass |  |
| generated_7 | node_1 | pass |  |
| generated_7 | not_node_1 | pass |  |
| generated_7 | node_3 | pass |  |
| generated_7 | not_node_3 | pass |  |
| generated_7 | node_4 | pass |  |
| generated_7 | not_node_4 | pass |  |
| generated_7 | node_5 | pass |  |
| generated_7 | not_node_5 | pass |  |
| generated_7 | node_6 | pass |  |
| generated_7 | not_node_6 | pass |  |
| generated_7 | node_7 | pass |  |
| generated_7 | not_node_7 | pass |  |
| generated_8 | node_1 | pass |  |
| generated_8 | not_node_1 | pass |  |
| generated_8 | node_3 | pass |  |
| generated_8 | not_node_3 | pass |  |
| generated_8 | node_4 | pass |  |
| generated_8 | not_node_4 | pass |  |
| generated_8 | node_5 | pass |  |
| generated_8 | not_node_5 | pass |  |
| generated_8 | node_6 | pass |  |
| generated_8 | not_node_6 | pass |  |
| generated_8 | node_7 | pass |  |
| generated_8 | not_node_7 | pass |  |

