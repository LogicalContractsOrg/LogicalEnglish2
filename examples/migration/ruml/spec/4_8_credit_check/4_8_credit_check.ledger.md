# Migration ledger: 4_8_credit_check

Source: RUML — credit-check.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 6 |
| approximated | 1 |
| residue | 0 |
| **total** | 7 |

Fidelity: **54 of 54** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| text(text_bgb_488) | text | encoded | a document of the twin (a text carried in the file) | bgb 488 | § 488 BGB – Darlehensvertrag |
| dp_annual_income | data point | encoded | a sentence that the scenarios state | the Jahreseinkommen of *a case* is *a number* | unit: EUR; validation: json([required= @(true),min=0]) |
| dp_credit_score | data point | encoded | a sentence that the scenarios state | the Bonitätsscore of *a case* is *a number* |  |
| node(1) | AND | encoded | AND of 2 children | Kreditprüfung holds for *a case* |  |
| node(2) | leaf | encoded | ruml:query dp_annual_income > 50000 | Einkommen ausreichend holds for *a case* |  |
| node(3) | leaf | encoded | ruml:query dp_credit_score >= 600 | Bonität ausreichend holds for *a case* |  |
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
| generated_2 | node_1 | pass |  |
| generated_2 | not_node_1 | pass |  |
| generated_2 | node_2 | pass |  |
| generated_2 | not_node_2 | pass |  |
| generated_2 | node_3 | pass |  |
| generated_2 | not_node_3 | pass |  |
| generated_3 | node_1 | pass |  |
| generated_3 | not_node_1 | pass |  |
| generated_3 | node_2 | pass |  |
| generated_3 | not_node_2 | pass |  |
| generated_3 | node_3 | pass |  |
| generated_3 | not_node_3 | pass |  |
| generated_4 | node_1 | pass |  |
| generated_4 | not_node_1 | pass |  |
| generated_4 | node_2 | pass |  |
| generated_4 | not_node_2 | pass |  |
| generated_4 | node_3 | pass |  |
| generated_4 | not_node_3 | pass |  |
| generated_5 | node_1 | pass |  |
| generated_5 | not_node_1 | pass |  |
| generated_5 | node_2 | pass |  |
| generated_5 | not_node_2 | pass |  |
| generated_5 | node_3 | pass |  |
| generated_5 | not_node_3 | pass |  |
| generated_6 | node_1 | pass |  |
| generated_6 | not_node_1 | pass |  |
| generated_6 | node_2 | pass |  |
| generated_6 | not_node_2 | pass |  |
| generated_6 | node_3 | pass |  |
| generated_6 | not_node_3 | pass |  |
| generated_7 | node_1 | pass |  |
| generated_7 | not_node_1 | pass |  |
| generated_7 | node_2 | pass |  |
| generated_7 | not_node_2 | pass |  |
| generated_7 | node_3 | pass |  |
| generated_7 | not_node_3 | pass |  |
| generated_8 | node_1 | pass |  |
| generated_8 | not_node_1 | pass |  |
| generated_8 | node_2 | pass |  |
| generated_8 | not_node_2 | pass |  |
| generated_8 | node_3 | pass |  |
| generated_8 | not_node_3 | pass |  |
| generated_9 | node_1 | pass |  |
| generated_9 | not_node_1 | pass |  |
| generated_9 | node_2 | pass |  |
| generated_9 | not_node_2 | pass |  |
| generated_9 | node_3 | pass |  |
| generated_9 | not_node_3 | pass |  |

