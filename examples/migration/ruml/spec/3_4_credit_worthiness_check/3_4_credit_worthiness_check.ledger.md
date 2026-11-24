# Migration ledger: 3_4_credit_worthiness_check

Source: RUML — credit-worthiness-check.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 3 |
| approximated | 1 |
| residue | 0 |
| **total** | 4 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| node(1) | AND | encoded | AND of 2 children | Credit worthiness check holds for *a case* |  |
| node(2) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Income verification holds for *a case* | RUML: undefined until decided |
| node(3) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Credit score check holds for *a case* | RUML: undefined until decided |
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

