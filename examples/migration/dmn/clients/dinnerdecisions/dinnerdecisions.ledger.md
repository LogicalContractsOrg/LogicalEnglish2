# Migration ledger: dinnerdecisions

Source: DMN — dinnerDecisions.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 1 |
| residue | 0 |
| **total** | 2 |

Fidelity: **12 of 12** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Beverages | decision table | encoded | decision table | Beverages |  |
| Dish | decision table | approximated | decision table | Dish | a column that compares numbers and has `-` cells: where its input is null the table has no answer, while DMN matches a row with `-` |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| spring_6 | q_d_rel_beverages | pass |  |
| spring_6 | q_d_dish | pass |  |
| spring_3 | q_d_rel_beverages | pass |  |
| spring_3 | q_d_dish | pass |  |
| fall_8 | q_d_rel_beverages | pass |  |
| fall_8 | q_d_dish | pass |  |
| winter_12 | q_d_rel_beverages | pass |  |
| winter_12 | q_d_dish | pass |  |
| winter_2 | q_d_rel_beverages | pass |  |
| winter_2 | q_d_dish | pass |  |
| summer_20 | q_d_rel_beverages | pass |  |
| summer_20 | q_d_dish | pass |  |

