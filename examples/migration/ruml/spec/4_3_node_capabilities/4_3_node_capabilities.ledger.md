# Migration ledger: 4_3_node_capabilities

Source: RUML — node-capabilities.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 5 |
| approximated | 3 |
| residue | 0 |
| **total** | 8 |

Fidelity: **32 of 32** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| dp_age | data point | encoded | a sentence that the scenarios state | the Alter of *a case* is *a number* |  |
| node(1) | AND | encoded | AND of 3 children | Zulassung des Antrags holds for *a case* | label: Zulassung des Antrags |
| node(2) | leaf | encoded | ruml:query dp_age >= 18 | Volljährigkeit nachgewiesen holds for *a case* | label: Volljährigkeit nachgewiesen |
| node(3) | leaf | encoded | ruml:query dp_age >= 18; ruml:ai-query: a judged sentence (the prompt: Ist der Antragsteller volljährig?) | Antragsteller volljährig holds for *a case* | label: Antragsteller volljährig |
| node(4) | leaf | encoded | ruml:query dp_age >= 18 | Ausnahmetatbestand holds for *a case* | label: Ausnahmetatbestand |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |
| capability(com.example/review-notes) | capability | approximated | a capability the twin does not use: kept in the original under sources/ |  |  |
| capability(ruml:draft/ai-annotations) | capability | approximated | a capability the twin does not use: kept in the original under sources/ |  |  |

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
| generated_2 | node_1 | pass |  |
| generated_2 | not_node_1 | pass |  |
| generated_2 | node_2 | pass |  |
| generated_2 | not_node_2 | pass |  |
| generated_2 | node_3 | pass |  |
| generated_2 | not_node_3 | pass |  |
| generated_2 | node_4 | pass |  |
| generated_2 | not_node_4 | pass |  |
| generated_3 | node_1 | pass |  |
| generated_3 | not_node_1 | pass |  |
| generated_3 | node_2 | pass |  |
| generated_3 | not_node_2 | pass |  |
| generated_3 | node_3 | pass |  |
| generated_3 | not_node_3 | pass |  |
| generated_3 | node_4 | pass |  |
| generated_3 | not_node_4 | pass |  |
| generated_4 | node_1 | pass |  |
| generated_4 | not_node_1 | pass |  |
| generated_4 | node_2 | pass |  |
| generated_4 | not_node_2 | pass |  |
| generated_4 | node_3 | pass |  |
| generated_4 | not_node_3 | pass |  |
| generated_4 | node_4 | pass |  |
| generated_4 | not_node_4 | pass |  |

