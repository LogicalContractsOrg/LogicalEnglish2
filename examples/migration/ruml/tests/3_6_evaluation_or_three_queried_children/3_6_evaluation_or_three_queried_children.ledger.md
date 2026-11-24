# Migration ledger: 3_6_evaluation_or_three_queried_children

Source: RUML — evaluation-or-three-queried-children.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 7 |
| approximated | 1 |
| residue | 0 |
| **total** | 8 |

Fidelity: **144 of 144** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| dp_answer_1 | data point | encoded | a sentence that the scenarios state | the Answer 1 of *a case* is *a text* | validation: json([required= @(true),enum=[yes,no,unknown]]) |
| dp_answer_2 | data point | encoded | a sentence that the scenarios state | the Answer 2 of *a case* is *a text* | validation: json([required= @(true),enum=[yes,no,unknown]]) |
| dp_answer_3 | data point | encoded | a sentence that the scenarios state | the Answer 3 of *a case* is *a text* | validation: json([required= @(true),enum=[yes,no,unknown]]) |
| node(1) | OR | encoded | OR of 3 children | root holds for *a case* |  |
| node(2) | leaf | encoded | ruml:query $lookup({'yes': true, 'no': false}, dp_answer_1) | One holds for *a case* |  |
| node(3) | leaf | encoded | ruml:query $lookup({'yes': true, 'no': false}, dp_answer_2) | Two holds for *a case* |  |
| node(4) | leaf | encoded | ruml:query $lookup({'yes': true, 'no': false}, dp_answer_3) | Three holds for *a case* |  |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| operator_or__complete__yes_yes_yes | node_1 | pass |  |
| operator_or__complete__yes_yes_yes | not_node_1 | pass |  |
| operator_or__complete__yes_yes_yes | node_2 | pass |  |
| operator_or__complete__yes_yes_yes | not_node_2 | pass |  |
| operator_or__complete__yes_yes_yes | node_3 | pass |  |
| operator_or__complete__yes_yes_yes | not_node_3 | pass |  |
| operator_or__complete__yes_yes_yes | node_4 | pass |  |
| operator_or__complete__yes_yes_yes | not_node_4 | pass |  |
| operator_or__complete__no_yes_yes | node_1 | pass |  |
| operator_or__complete__no_yes_yes | not_node_1 | pass |  |
| operator_or__complete__no_yes_yes | node_2 | pass |  |
| operator_or__complete__no_yes_yes | not_node_2 | pass |  |
| operator_or__complete__no_yes_yes | node_3 | pass |  |
| operator_or__complete__no_yes_yes | not_node_3 | pass |  |
| operator_or__complete__no_yes_yes | node_4 | pass |  |
| operator_or__complete__no_yes_yes | not_node_4 | pass |  |
| operator_or__complete__no_no_no | node_1 | pass |  |
| operator_or__complete__no_no_no | not_node_1 | pass |  |
| operator_or__complete__no_no_no | node_2 | pass |  |
| operator_or__complete__no_no_no | not_node_2 | pass |  |
| operator_or__complete__no_no_no | node_3 | pass |  |
| operator_or__complete__no_no_no | not_node_3 | pass |  |
| operator_or__complete__no_no_no | node_4 | pass |  |
| operator_or__complete__no_no_no | not_node_4 | pass |  |
| operator_or__complete__unknown_yes_no | node_1 | pass |  |
| operator_or__complete__unknown_yes_no | not_node_1 | pass |  |
| operator_or__complete__unknown_yes_no | node_2 | pass |  |
| operator_or__complete__unknown_yes_no | not_node_2 | pass |  |
| operator_or__complete__unknown_yes_no | node_3 | pass |  |
| operator_or__complete__unknown_yes_no | not_node_3 | pass |  |
| operator_or__complete__unknown_yes_no | node_4 | pass |  |
| operator_or__complete__unknown_yes_no | not_node_4 | pass |  |
| operator_or__complete__no_yes_unknown | node_1 | pass |  |
| operator_or__complete__no_yes_unknown | not_node_1 | pass |  |
| operator_or__complete__no_yes_unknown | node_2 | pass |  |
| operator_or__complete__no_yes_unknown | not_node_2 | pass |  |
| operator_or__complete__no_yes_unknown | node_3 | pass |  |
| operator_or__complete__no_yes_unknown | not_node_3 | pass |  |
| operator_or__complete__no_yes_unknown | node_4 | pass |  |
| operator_or__complete__no_yes_unknown | not_node_4 | pass |  |
| operator_or__complete__no_unknown_no | node_1 | pass |  |
| operator_or__complete__no_unknown_no | not_node_1 | pass |  |
| operator_or__complete__no_unknown_no | node_2 | pass |  |
| operator_or__complete__no_unknown_no | not_node_2 | pass |  |
| operator_or__complete__no_unknown_no | node_3 | pass |  |
| operator_or__complete__no_unknown_no | not_node_3 | pass |  |
| operator_or__complete__no_unknown_no | node_4 | pass |  |
| operator_or__complete__no_unknown_no | not_node_4 | pass |  |
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

