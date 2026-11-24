# Migration ledger: 3_7_credit_approval

Source: RUML — credit-approval.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 9 |
| approximated | 1 |
| residue | 0 |
| **total** | 10 |

Fidelity: **18 of 18** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| node(1) | AND | encoded | AND of 2 children | Approve credit holds for *a case* |  |
| node(2) | OR | encoded | OR of 2 children | Income verification holds for *a case* |  |
| node(7) | NOT_AND | encoded | NOT_AND of 2 children: the negation of a second sentence | No negative indicators holds for *a case* |  |
| node(3) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | High income holds for *a case* | RUML: undefined until decided |
| node(4) | AND | encoded | AND of 2 children | Medium income collateral holds for *a case* |  |
| node(8) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Insolvency present holds for *a case* | RUML: undefined until decided |
| node(9) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Negative schufa entry holds for *a case* | RUML: undefined until decided |
| node(5) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Medium income holds for *a case* | RUML: undefined until decided |
| node(6) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Collateral available holds for *a case* | RUML: undefined until decided |
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
| generated_1 | node_5 | pass |  |
| generated_1 | not_node_5 | pass |  |
| generated_1 | node_6 | pass |  |
| generated_1 | not_node_6 | pass |  |
| generated_1 | node_7 | pass |  |
| generated_1 | not_node_7 | pass |  |
| generated_1 | node_8 | pass |  |
| generated_1 | not_node_8 | pass |  |
| generated_1 | node_9 | pass |  |
| generated_1 | not_node_9 | pass |  |

