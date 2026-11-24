# Migration ledger: 6_4_contract_negotiation

Source: RUML — contract-negotiation.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 7 |
| approximated | 2 |
| residue | 0 |
| **total** | 9 |

Fidelity: **76 of 76** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| dp_legal_capacity | data point | encoded | a sentence that the scenarios state | the Vertragsfähigkeit of *a case* is *a truth value* |  |
| dp_offer_accepted | data point | encoded | a sentence that the scenarios state | the Angebot angenommen of *a case* is *a truth value* |  |
| dp_negotiation_cancelled | data point | encoded | a sentence that the scenarios state | the Verhandlung abgebrochen of *a case* is *a truth value* |  |
| node(1) | AND | encoded | AND of 2 children | Vertragsabschluss holds for *a case* | label: Vertragsabschluss |
| node(2) | leaf | encoded | ruml:query dp_legal_capacity = true | Vertragsfähigkeit geprüft holds for *a case* | label: Vertragsfähigkeit geprüft |
| node(4) | XOR | approximated | a recursive node: its exits, and an assumption where no exit decides | Verhandlungsrunde holds for *a case* | label: Verhandlungsrunde; every round of RUML 1.0 sees the same data, so the twin answers as RUML's evaluator does at its depth limit |
| node(5) | leaf | encoded | ruml:query dp_offer_accepted = true | Angebot angenommen holds for *a case* | label: Angebot angenommen |
| node(6) | leaf | encoded | ruml:query dp_negotiation_cancelled = true | Verhandlung abgebrochen holds for *a case* | label: Verhandlung abgebrochen |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |
| generated_1 | node_2 | pass |  |
| generated_1 | not_node_2 | pass |  |
| generated_1 | node_5 | pass |  |
| generated_1 | not_node_5 | pass |  |
| generated_1 | node_6 | pass |  |
| generated_1 | not_node_6 | pass |  |
| generated_2 | node_1 | pass |  |
| generated_2 | not_node_1 | pass |  |
| generated_2 | node_2 | pass |  |
| generated_2 | not_node_2 | pass |  |
| generated_2 | node_5 | pass |  |
| generated_2 | not_node_5 | pass |  |
| generated_2 | node_6 | pass |  |
| generated_2 | not_node_6 | pass |  |
| generated_3 | node_1 | pass |  |
| generated_3 | not_node_1 | pass |  |
| generated_3 | node_2 | pass |  |
| generated_3 | not_node_2 | pass |  |
| generated_3 | node_5 | pass |  |
| generated_3 | not_node_5 | pass |  |
| generated_3 | node_6 | pass |  |
| generated_3 | not_node_6 | pass |  |
| generated_4 | node_1 | pass |  |
| generated_4 | not_node_1 | pass |  |
| generated_4 | node_2 | pass |  |
| generated_4 | not_node_2 | pass |  |
| generated_4 | node_5 | pass |  |
| generated_4 | not_node_5 | pass |  |
| generated_4 | node_6 | pass |  |
| generated_4 | not_node_6 | pass |  |
| generated_5 | node_1 | pass |  |
| generated_5 | not_node_1 | pass |  |
| generated_5 | node_2 | pass |  |
| generated_5 | not_node_2 | pass |  |
| generated_5 | node_5 | pass |  |
| generated_5 | not_node_5 | pass |  |
| generated_5 | node_6 | pass |  |
| generated_5 | not_node_6 | pass |  |
| generated_6 | node_1 | pass |  |
| generated_6 | not_node_1 | pass |  |
| generated_6 | node_2 | pass |  |
| generated_6 | not_node_2 | pass |  |
| generated_6 | node_5 | pass |  |
| generated_6 | not_node_5 | pass |  |
| generated_6 | node_6 | pass |  |
| generated_6 | not_node_6 | pass |  |
| generated_7 | node_1 | pass |  |
| generated_7 | not_node_1 | pass |  |
| generated_7 | node_2 | pass |  |
| generated_7 | not_node_2 | pass |  |
| generated_7 | node_5 | pass |  |
| generated_7 | not_node_5 | pass |  |
| generated_7 | node_6 | pass |  |
| generated_7 | not_node_6 | pass |  |
| generated_8 | node_1 | pass |  |
| generated_8 | not_node_1 | pass |  |
| generated_8 | node_2 | pass |  |
| generated_8 | not_node_2 | pass |  |
| generated_8 | node_4 | pass |  |
| generated_8 | not_node_4 | pass |  |
| generated_8 | node_5 | pass |  |
| generated_8 | not_node_5 | pass |  |
| generated_8 | node_6 | pass |  |
| generated_8 | not_node_6 | pass |  |
| generated_9 | node_1 | pass |  |
| generated_9 | not_node_1 | pass |  |
| generated_9 | node_2 | pass |  |
| generated_9 | not_node_2 | pass |  |
| generated_9 | node_4 | pass |  |
| generated_9 | not_node_4 | pass |  |
| generated_9 | node_5 | pass |  |
| generated_9 | not_node_5 | pass |  |
| generated_9 | node_6 | pass |  |
| generated_9 | not_node_6 | pass |  |

