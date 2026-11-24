# Migration ledger: 6_5_nested_credit_checks

Source: RUML — nested-credit-checks.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 11 |
| approximated | 1 |
| residue | 0 |
| **total** | 12 |

Fidelity: **176 of 176** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| dp_identity_verified | data point | encoded | a sentence that the scenarios state | the Identität geprüft of *a case* is *a truth value* |  |
| dp_income | data point | encoded | a sentence that the scenarios state | the Einkommen of *a case* is *a number* |  |
| dp_schufa | data point | encoded | a sentence that the scenarios state | the Schufa Score of *a case* is *a number* |  |
| node(1) | AND | encoded | AND of 3 children | Root holds for *a case* |  |
| node(10) | AND | encoded | AND of 2 children | Hauptprüfung holds for *a case* |  |
| node(2) | OR | encoded | OR of 1 children | Alternative holds for *a case* |  |
| node(3) | OR | encoded | OR of 1 children | Schnellprüfung holds for *a case* |  |
| node(11) | leaf | encoded | ruml:query dp_identity_verified = true | Identitätsprüfung holds for *a case* |  |
| node(20) | AND | encoded | AND of 2 children | Bonitätsprüfung holds for *a case* |  |
| node(21) | leaf | encoded | ruml:query dp_income > 30000 | Einkommensprüfung holds for *a case* |  |
| node(22) | leaf | encoded | ruml:query dp_schufa >= 600 | Schufa Prüfung holds for *a case* |  |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |
| generated_1 | node_10 | pass |  |
| generated_1 | not_node_10 | pass |  |
| generated_1 | node_11 | pass |  |
| generated_1 | not_node_11 | pass |  |
| generated_1 | node_2 | pass |  |
| generated_1 | not_node_2 | pass |  |
| generated_1 | node_20 | pass |  |
| generated_1 | not_node_20 | pass |  |
| generated_1 | node_21 | pass |  |
| generated_1 | not_node_21 | pass |  |
| generated_1 | node_22 | pass |  |
| generated_1 | not_node_22 | pass |  |
| generated_1 | node_3 | pass |  |
| generated_1 | not_node_3 | pass |  |
| generated_2 | node_1 | pass |  |
| generated_2 | not_node_1 | pass |  |
| generated_2 | node_10 | pass |  |
| generated_2 | not_node_10 | pass |  |
| generated_2 | node_11 | pass |  |
| generated_2 | not_node_11 | pass |  |
| generated_2 | node_2 | pass |  |
| generated_2 | not_node_2 | pass |  |
| generated_2 | node_20 | pass |  |
| generated_2 | not_node_20 | pass |  |
| generated_2 | node_21 | pass |  |
| generated_2 | not_node_21 | pass |  |
| generated_2 | node_22 | pass |  |
| generated_2 | not_node_22 | pass |  |
| generated_2 | node_3 | pass |  |
| generated_2 | not_node_3 | pass |  |
| generated_3 | node_1 | pass |  |
| generated_3 | not_node_1 | pass |  |
| generated_3 | node_10 | pass |  |
| generated_3 | not_node_10 | pass |  |
| generated_3 | node_11 | pass |  |
| generated_3 | not_node_11 | pass |  |
| generated_3 | node_2 | pass |  |
| generated_3 | not_node_2 | pass |  |
| generated_3 | node_20 | pass |  |
| generated_3 | not_node_20 | pass |  |
| generated_3 | node_21 | pass |  |
| generated_3 | not_node_21 | pass |  |
| generated_3 | node_22 | pass |  |
| generated_3 | not_node_22 | pass |  |
| generated_3 | node_3 | pass |  |
| generated_3 | not_node_3 | pass |  |
| generated_4 | node_1 | pass |  |
| generated_4 | not_node_1 | pass |  |
| generated_4 | node_10 | pass |  |
| generated_4 | not_node_10 | pass |  |
| generated_4 | node_11 | pass |  |
| generated_4 | not_node_11 | pass |  |
| generated_4 | node_2 | pass |  |
| generated_4 | not_node_2 | pass |  |
| generated_4 | node_20 | pass |  |
| generated_4 | not_node_20 | pass |  |
| generated_4 | node_21 | pass |  |
| generated_4 | not_node_21 | pass |  |
| generated_4 | node_22 | pass |  |
| generated_4 | not_node_22 | pass |  |
| generated_4 | node_3 | pass |  |
| generated_4 | not_node_3 | pass |  |
| generated_5 | node_1 | pass |  |
| generated_5 | not_node_1 | pass |  |
| generated_5 | node_10 | pass |  |
| generated_5 | not_node_10 | pass |  |
| generated_5 | node_11 | pass |  |
| generated_5 | not_node_11 | pass |  |
| generated_5 | node_2 | pass |  |
| generated_5 | not_node_2 | pass |  |
| generated_5 | node_20 | pass |  |
| generated_5 | not_node_20 | pass |  |
| generated_5 | node_21 | pass |  |
| generated_5 | not_node_21 | pass |  |
| generated_5 | node_22 | pass |  |
| generated_5 | not_node_22 | pass |  |
| generated_5 | node_3 | pass |  |
| generated_5 | not_node_3 | pass |  |
| generated_6 | node_1 | pass |  |
| generated_6 | not_node_1 | pass |  |
| generated_6 | node_10 | pass |  |
| generated_6 | not_node_10 | pass |  |
| generated_6 | node_11 | pass |  |
| generated_6 | not_node_11 | pass |  |
| generated_6 | node_2 | pass |  |
| generated_6 | not_node_2 | pass |  |
| generated_6 | node_20 | pass |  |
| generated_6 | not_node_20 | pass |  |
| generated_6 | node_21 | pass |  |
| generated_6 | not_node_21 | pass |  |
| generated_6 | node_22 | pass |  |
| generated_6 | not_node_22 | pass |  |
| generated_6 | node_3 | pass |  |
| generated_6 | not_node_3 | pass |  |
| generated_7 | node_1 | pass |  |
| generated_7 | not_node_1 | pass |  |
| generated_7 | node_10 | pass |  |
| generated_7 | not_node_10 | pass |  |
| generated_7 | node_11 | pass |  |
| generated_7 | not_node_11 | pass |  |
| generated_7 | node_2 | pass |  |
| generated_7 | not_node_2 | pass |  |
| generated_7 | node_20 | pass |  |
| generated_7 | not_node_20 | pass |  |
| generated_7 | node_21 | pass |  |
| generated_7 | not_node_21 | pass |  |
| generated_7 | node_22 | pass |  |
| generated_7 | not_node_22 | pass |  |
| generated_7 | node_3 | pass |  |
| generated_7 | not_node_3 | pass |  |
| generated_8 | node_1 | pass |  |
| generated_8 | not_node_1 | pass |  |
| generated_8 | node_10 | pass |  |
| generated_8 | not_node_10 | pass |  |
| generated_8 | node_11 | pass |  |
| generated_8 | not_node_11 | pass |  |
| generated_8 | node_2 | pass |  |
| generated_8 | not_node_2 | pass |  |
| generated_8 | node_20 | pass |  |
| generated_8 | not_node_20 | pass |  |
| generated_8 | node_21 | pass |  |
| generated_8 | not_node_21 | pass |  |
| generated_8 | node_22 | pass |  |
| generated_8 | not_node_22 | pass |  |
| generated_8 | node_3 | pass |  |
| generated_8 | not_node_3 | pass |  |
| generated_9 | node_1 | pass |  |
| generated_9 | not_node_1 | pass |  |
| generated_9 | node_10 | pass |  |
| generated_9 | not_node_10 | pass |  |
| generated_9 | node_11 | pass |  |
| generated_9 | not_node_11 | pass |  |
| generated_9 | node_2 | pass |  |
| generated_9 | not_node_2 | pass |  |
| generated_9 | node_20 | pass |  |
| generated_9 | not_node_20 | pass |  |
| generated_9 | node_21 | pass |  |
| generated_9 | not_node_21 | pass |  |
| generated_9 | node_22 | pass |  |
| generated_9 | not_node_22 | pass |  |
| generated_9 | node_3 | pass |  |
| generated_9 | not_node_3 | pass |  |
| generated_10 | node_1 | pass |  |
| generated_10 | not_node_1 | pass |  |
| generated_10 | node_10 | pass |  |
| generated_10 | not_node_10 | pass |  |
| generated_10 | node_11 | pass |  |
| generated_10 | not_node_11 | pass |  |
| generated_10 | node_2 | pass |  |
| generated_10 | not_node_2 | pass |  |
| generated_10 | node_20 | pass |  |
| generated_10 | not_node_20 | pass |  |
| generated_10 | node_21 | pass |  |
| generated_10 | not_node_21 | pass |  |
| generated_10 | node_22 | pass |  |
| generated_10 | not_node_22 | pass |  |
| generated_10 | node_3 | pass |  |
| generated_10 | not_node_3 | pass |  |
| generated_11 | node_1 | pass |  |
| generated_11 | not_node_1 | pass |  |
| generated_11 | node_10 | pass |  |
| generated_11 | not_node_10 | pass |  |
| generated_11 | node_11 | pass |  |
| generated_11 | not_node_11 | pass |  |
| generated_11 | node_2 | pass |  |
| generated_11 | not_node_2 | pass |  |
| generated_11 | node_20 | pass |  |
| generated_11 | not_node_20 | pass |  |
| generated_11 | node_21 | pass |  |
| generated_11 | not_node_21 | pass |  |
| generated_11 | node_22 | pass |  |
| generated_11 | not_node_22 | pass |  |
| generated_11 | node_3 | pass |  |
| generated_11 | not_node_3 | pass |  |

