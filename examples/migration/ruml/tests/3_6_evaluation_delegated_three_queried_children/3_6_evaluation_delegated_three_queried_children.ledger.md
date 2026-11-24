# Migration ledger: 3_6_evaluation_delegated_three_queried_children

Source: RUML — evaluation-delegated-three-queried-children.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 7 |
| approximated | 1 |
| residue | 0 |
| **total** | 8 |

Fidelity: **96 of 96** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| dp_answer_1 | data point | encoded | a sentence that the scenarios state | the Answer 1 of *a case* is *a text* | validation: json([required= @(true),enum=[yes,no,unknown]]) |
| dp_answer_2 | data point | encoded | a sentence that the scenarios state | the Answer 2 of *a case* is *a text* | validation: json([required= @(true),enum=[yes,no,unknown]]) |
| dp_answer_3 | data point | encoded | a sentence that the scenarios state | the Answer 3 of *a case* is *a text* | validation: json([required= @(true),enum=[yes,no,unknown]]) |
| node(1) | DELEGATED | encoded | DELEGATED: $count($children[status = 'true']) >= 2 | root holds for *a case* | exact: undefined whenever a child is undefined, as the combiner contract says (§3.6.4) |
| node(2) | leaf | encoded | ruml:query $lookup({'yes': true, 'no': false}, dp_answer_1) | One holds for *a case* |  |
| node(3) | leaf | encoded | ruml:query $lookup({'yes': true, 'no': false}, dp_answer_2) | Two holds for *a case* |  |
| node(4) | leaf | encoded | ruml:query $lookup({'yes': true, 'no': false}, dp_answer_3) | Three holds for *a case* |  |
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
| generated_5 | node_1 | pass |  |
| generated_5 | not_node_1 | pass |  |
| generated_5 | node_2 | pass |  |
| generated_5 | not_node_2 | pass |  |
| generated_5 | node_3 | pass |  |
| generated_5 | not_node_3 | pass |  |
| generated_5 | node_4 | pass |  |
| generated_5 | not_node_4 | pass |  |
| generated_6 | node_1 | pass |  |
| generated_6 | not_node_1 | pass |  |
| generated_6 | node_2 | pass |  |
| generated_6 | not_node_2 | pass |  |
| generated_6 | node_3 | pass |  |
| generated_6 | not_node_3 | pass |  |
| generated_6 | node_4 | pass |  |
| generated_6 | not_node_4 | pass |  |
| generated_7 | node_1 | pass |  |
| generated_7 | not_node_1 | pass |  |
| generated_7 | node_2 | pass |  |
| generated_7 | not_node_2 | pass |  |
| generated_7 | node_3 | pass |  |
| generated_7 | not_node_3 | pass |  |
| generated_7 | node_4 | pass |  |
| generated_7 | not_node_4 | pass |  |
| generated_8 | node_1 | pass |  |
| generated_8 | not_node_1 | pass |  |
| generated_8 | node_2 | pass |  |
| generated_8 | not_node_2 | pass |  |
| generated_8 | node_3 | pass |  |
| generated_8 | not_node_3 | pass |  |
| generated_8 | node_4 | pass |  |
| generated_8 | not_node_4 | pass |  |
| generated_9 | node_1 | pass |  |
| generated_9 | not_node_1 | pass |  |
| generated_9 | node_2 | pass |  |
| generated_9 | not_node_2 | pass |  |
| generated_9 | node_3 | pass |  |
| generated_9 | not_node_3 | pass |  |
| generated_9 | node_4 | pass |  |
| generated_9 | not_node_4 | pass |  |
| generated_10 | node_1 | pass |  |
| generated_10 | not_node_1 | pass |  |
| generated_10 | node_2 | pass |  |
| generated_10 | not_node_2 | pass |  |
| generated_10 | node_3 | pass |  |
| generated_10 | not_node_3 | pass |  |
| generated_10 | node_4 | pass |  |
| generated_10 | not_node_4 | pass |  |
| generated_11 | node_1 | pass |  |
| generated_11 | not_node_1 | pass |  |
| generated_11 | node_2 | pass |  |
| generated_11 | not_node_2 | pass |  |
| generated_11 | node_3 | pass |  |
| generated_11 | not_node_3 | pass |  |
| generated_11 | node_4 | pass |  |
| generated_11 | not_node_4 | pass |  |
| generated_12 | node_1 | pass |  |
| generated_12 | not_node_1 | pass |  |
| generated_12 | node_2 | pass |  |
| generated_12 | not_node_2 | pass |  |
| generated_12 | node_3 | pass |  |
| generated_12 | not_node_3 | pass |  |
| generated_12 | node_4 | pass |  |
| generated_12 | not_node_4 | pass |  |

