# Migration ledger: 6_2_accept_modular_with_single_parent

Source: RUML — accept-modular-with-single-parent.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 5 |
| approximated | 1 |
| residue | 0 |
| **total** | 6 |

Fidelity: **10 of 10** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| node(1) | AND | encoded | AND of 2 children | Antrag holds for *a case* |  |
| node(2) | AND | encoded | AND of 1 children | Antrag node 2 holds for *a case* |  |
| node(3) | AND | encoded | AND of 1 children | Antrag b holds for *a case* |  |
| node(5) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Nur einmal referenziert holds for *a case* | RUML: undefined until decided |
| node(6) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Einfach referenziert holds for *a case* | RUML: undefined until decided |
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
| generated_1 | node_5 | pass |  |
| generated_1 | not_node_5 | pass |  |
| generated_1 | node_6 | pass |  |
| generated_1 | not_node_6 | pass |  |

