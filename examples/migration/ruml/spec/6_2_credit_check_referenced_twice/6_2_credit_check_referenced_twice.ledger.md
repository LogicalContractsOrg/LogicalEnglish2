# Migration ledger: 6_2_credit_check_referenced_twice

Source: RUML — credit-check-referenced-twice.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 11 |
| approximated | 1 |
| residue | 0 |
| **total** | 12 |

Fidelity: **210 of 210** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| dp_age | data point | encoded | a sentence that the scenarios state | the Alter of *a case* is *a number* |  |
| dp_income | data point | encoded | a sentence that the scenarios state | the Einkommen of *a case* is *a number* |  |
| dp_schufa | data point | encoded | a sentence that the scenarios state | the Schufa Score of *a case* is *a number* |  |
| dp_guarantor | data point | encoded | a sentence that the scenarios state | the Bürgschaft vorhanden of *a case* is *a truth value* |  |
| node(1) | AND | encoded | AND of 3 children | Hauptprüfung holds for *a case* | label: Hauptprüfung |
| node(2) | leaf | encoded | ruml:query dp_age >= 18 | Antragsteller volljährig holds for *a case* | label: Antragsteller volljährig |
| node(8) | AND | encoded | AND of 2 children | Standardprüfung Bonität holds for *a case* | label: Standardprüfung Bonität |
| node(10) | OR | encoded | OR of 2 children | Alternative Prüfungen holds for *a case* | label: Alternative Prüfungen |
| node(9) | leaf | encoded | ruml:query dp_income > 30000 | Einkommensprüfung holds for *a case* | label: Einkommensprüfung |
| node(11) | leaf | encoded | ruml:query dp_schufa >= 600 | Schufa Score holds for *a case* | label: Schufa-Score |
| node(12) | leaf | encoded | ruml:query dp_guarantor = true | Bürgschaft vorhanden holds for *a case* | label: Bürgschaft vorhanden |
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
| generated_1 | node_12 | pass |  |
| generated_1 | not_node_12 | pass |  |
| generated_1 | node_2 | pass |  |
| generated_1 | not_node_2 | pass |  |
| generated_1 | node_8 | pass |  |
| generated_1 | not_node_8 | pass |  |
| generated_1 | node_9 | pass |  |
| generated_1 | not_node_9 | pass |  |
| generated_2 | node_1 | pass |  |
| generated_2 | not_node_1 | pass |  |
| generated_2 | node_10 | pass |  |
| generated_2 | not_node_10 | pass |  |
| generated_2 | node_11 | pass |  |
| generated_2 | not_node_11 | pass |  |
| generated_2 | node_12 | pass |  |
| generated_2 | not_node_12 | pass |  |
| generated_2 | node_2 | pass |  |
| generated_2 | not_node_2 | pass |  |
| generated_2 | node_8 | pass |  |
| generated_2 | not_node_8 | pass |  |
| generated_2 | node_9 | pass |  |
| generated_2 | not_node_9 | pass |  |
| generated_3 | node_1 | pass |  |
| generated_3 | not_node_1 | pass |  |
| generated_3 | node_10 | pass |  |
| generated_3 | not_node_10 | pass |  |
| generated_3 | node_11 | pass |  |
| generated_3 | not_node_11 | pass |  |
| generated_3 | node_12 | pass |  |
| generated_3 | not_node_12 | pass |  |
| generated_3 | node_2 | pass |  |
| generated_3 | not_node_2 | pass |  |
| generated_3 | node_8 | pass |  |
| generated_3 | not_node_8 | pass |  |
| generated_3 | node_9 | pass |  |
| generated_3 | not_node_9 | pass |  |
| generated_4 | node_1 | pass |  |
| generated_4 | not_node_1 | pass |  |
| generated_4 | node_10 | pass |  |
| generated_4 | not_node_10 | pass |  |
| generated_4 | node_11 | pass |  |
| generated_4 | not_node_11 | pass |  |
| generated_4 | node_12 | pass |  |
| generated_4 | not_node_12 | pass |  |
| generated_4 | node_2 | pass |  |
| generated_4 | not_node_2 | pass |  |
| generated_4 | node_8 | pass |  |
| generated_4 | not_node_8 | pass |  |
| generated_4 | node_9 | pass |  |
| generated_4 | not_node_9 | pass |  |
| generated_5 | node_1 | pass |  |
| generated_5 | not_node_1 | pass |  |
| generated_5 | node_10 | pass |  |
| generated_5 | not_node_10 | pass |  |
| generated_5 | node_11 | pass |  |
| generated_5 | not_node_11 | pass |  |
| generated_5 | node_12 | pass |  |
| generated_5 | not_node_12 | pass |  |
| generated_5 | node_2 | pass |  |
| generated_5 | not_node_2 | pass |  |
| generated_5 | node_8 | pass |  |
| generated_5 | not_node_8 | pass |  |
| generated_5 | node_9 | pass |  |
| generated_5 | not_node_9 | pass |  |
| generated_6 | node_1 | pass |  |
| generated_6 | not_node_1 | pass |  |
| generated_6 | node_10 | pass |  |
| generated_6 | not_node_10 | pass |  |
| generated_6 | node_11 | pass |  |
| generated_6 | not_node_11 | pass |  |
| generated_6 | node_12 | pass |  |
| generated_6 | not_node_12 | pass |  |
| generated_6 | node_2 | pass |  |
| generated_6 | not_node_2 | pass |  |
| generated_6 | node_8 | pass |  |
| generated_6 | not_node_8 | pass |  |
| generated_6 | node_9 | pass |  |
| generated_6 | not_node_9 | pass |  |
| generated_7 | node_1 | pass |  |
| generated_7 | not_node_1 | pass |  |
| generated_7 | node_10 | pass |  |
| generated_7 | not_node_10 | pass |  |
| generated_7 | node_11 | pass |  |
| generated_7 | not_node_11 | pass |  |
| generated_7 | node_12 | pass |  |
| generated_7 | not_node_12 | pass |  |
| generated_7 | node_2 | pass |  |
| generated_7 | not_node_2 | pass |  |
| generated_7 | node_8 | pass |  |
| generated_7 | not_node_8 | pass |  |
| generated_7 | node_9 | pass |  |
| generated_7 | not_node_9 | pass |  |
| generated_8 | node_1 | pass |  |
| generated_8 | not_node_1 | pass |  |
| generated_8 | node_10 | pass |  |
| generated_8 | not_node_10 | pass |  |
| generated_8 | node_11 | pass |  |
| generated_8 | not_node_11 | pass |  |
| generated_8 | node_12 | pass |  |
| generated_8 | not_node_12 | pass |  |
| generated_8 | node_2 | pass |  |
| generated_8 | not_node_2 | pass |  |
| generated_8 | node_8 | pass |  |
| generated_8 | not_node_8 | pass |  |
| generated_8 | node_9 | pass |  |
| generated_8 | not_node_9 | pass |  |
| generated_9 | node_1 | pass |  |
| generated_9 | not_node_1 | pass |  |
| generated_9 | node_10 | pass |  |
| generated_9 | not_node_10 | pass |  |
| generated_9 | node_11 | pass |  |
| generated_9 | not_node_11 | pass |  |
| generated_9 | node_12 | pass |  |
| generated_9 | not_node_12 | pass |  |
| generated_9 | node_2 | pass |  |
| generated_9 | not_node_2 | pass |  |
| generated_9 | node_8 | pass |  |
| generated_9 | not_node_8 | pass |  |
| generated_9 | node_9 | pass |  |
| generated_9 | not_node_9 | pass |  |
| generated_10 | node_1 | pass |  |
| generated_10 | not_node_1 | pass |  |
| generated_10 | node_10 | pass |  |
| generated_10 | not_node_10 | pass |  |
| generated_10 | node_11 | pass |  |
| generated_10 | not_node_11 | pass |  |
| generated_10 | node_12 | pass |  |
| generated_10 | not_node_12 | pass |  |
| generated_10 | node_2 | pass |  |
| generated_10 | not_node_2 | pass |  |
| generated_10 | node_8 | pass |  |
| generated_10 | not_node_8 | pass |  |
| generated_10 | node_9 | pass |  |
| generated_10 | not_node_9 | pass |  |
| generated_11 | node_1 | pass |  |
| generated_11 | not_node_1 | pass |  |
| generated_11 | node_10 | pass |  |
| generated_11 | not_node_10 | pass |  |
| generated_11 | node_11 | pass |  |
| generated_11 | not_node_11 | pass |  |
| generated_11 | node_12 | pass |  |
| generated_11 | not_node_12 | pass |  |
| generated_11 | node_2 | pass |  |
| generated_11 | not_node_2 | pass |  |
| generated_11 | node_8 | pass |  |
| generated_11 | not_node_8 | pass |  |
| generated_11 | node_9 | pass |  |
| generated_11 | not_node_9 | pass |  |
| generated_12 | node_1 | pass |  |
| generated_12 | not_node_1 | pass |  |
| generated_12 | node_10 | pass |  |
| generated_12 | not_node_10 | pass |  |
| generated_12 | node_11 | pass |  |
| generated_12 | not_node_11 | pass |  |
| generated_12 | node_12 | pass |  |
| generated_12 | not_node_12 | pass |  |
| generated_12 | node_2 | pass |  |
| generated_12 | not_node_2 | pass |  |
| generated_12 | node_8 | pass |  |
| generated_12 | not_node_8 | pass |  |
| generated_12 | node_9 | pass |  |
| generated_12 | not_node_9 | pass |  |
| generated_13 | node_1 | pass |  |
| generated_13 | not_node_1 | pass |  |
| generated_13 | node_10 | pass |  |
| generated_13 | not_node_10 | pass |  |
| generated_13 | node_11 | pass |  |
| generated_13 | not_node_11 | pass |  |
| generated_13 | node_12 | pass |  |
| generated_13 | not_node_12 | pass |  |
| generated_13 | node_2 | pass |  |
| generated_13 | not_node_2 | pass |  |
| generated_13 | node_8 | pass |  |
| generated_13 | not_node_8 | pass |  |
| generated_13 | node_9 | pass |  |
| generated_13 | not_node_9 | pass |  |
| generated_14 | node_1 | pass |  |
| generated_14 | not_node_1 | pass |  |
| generated_14 | node_10 | pass |  |
| generated_14 | not_node_10 | pass |  |
| generated_14 | node_11 | pass |  |
| generated_14 | not_node_11 | pass |  |
| generated_14 | node_12 | pass |  |
| generated_14 | not_node_12 | pass |  |
| generated_14 | node_2 | pass |  |
| generated_14 | not_node_2 | pass |  |
| generated_14 | node_8 | pass |  |
| generated_14 | not_node_8 | pass |  |
| generated_14 | node_9 | pass |  |
| generated_14 | not_node_9 | pass |  |
| generated_15 | node_1 | pass |  |
| generated_15 | not_node_1 | pass |  |
| generated_15 | node_10 | pass |  |
| generated_15 | not_node_10 | pass |  |
| generated_15 | node_11 | pass |  |
| generated_15 | not_node_11 | pass |  |
| generated_15 | node_12 | pass |  |
| generated_15 | not_node_12 | pass |  |
| generated_15 | node_2 | pass |  |
| generated_15 | not_node_2 | pass |  |
| generated_15 | node_8 | pass |  |
| generated_15 | not_node_8 | pass |  |
| generated_15 | node_9 | pass |  |
| generated_15 | not_node_9 | pass |  |

