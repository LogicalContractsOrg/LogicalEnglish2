# Migration ledger: 3_6_accept_delegated_nondeterministic_expression

Source: RUML — accept-delegated-nondeterministic-expression.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 3 |
| approximated | 1 |
| residue | 1 |
| **total** | 5 |

Fidelity: **8 of 8** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| node(1) | node | residue | the JSONata expression $random() | Stichprobe ausgewählt holds for *a case* |  |
| node(2) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Merkmal 1 holds for *a case* | RUML: undefined until decided |
| node(3) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Merkmal 2 holds for *a case* | RUML: undefined until decided |
| node(4) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Merkmal 3 holds for *a case* | RUML: undefined until decided |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Residue

- **node(1)** (node) — the JSONata expression $random(); in the program: Stichprobe ausgewählt holds for *a case*. 

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

