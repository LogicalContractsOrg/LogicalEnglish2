# Migration ledger: 5_1_foerderantrag

Source: RUML — foerderantrag.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 10 |
| approximated | 1 |
| residue | 1 |
| **total** | 12 |

Fidelity: **168 of 168** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| dp_age | data point | encoded | a sentence that the scenarios state | the Alter des Antragstellers of *a case* is *a number* |  |
| dp_income | data point | encoded | a sentence that the scenarios state | the Jahreseinkommen of *a case* is *a number* | unit: EUR |
| dp_hardship | data point | encoded | a sentence that the scenarios state | the Härtefall anerkannt of *a case* is *a truth value* |  |
| dp_state | data point | encoded | a sentence that the scenarios state | the Bundesland des Wohnsitzes of *a case* is *a text* |  |
| node(1) | AND | encoded | AND of 3 children | Fördervoraussetzungen holds for *a case* | label: Fördervoraussetzungen |
| node(2) | leaf | encoded | ruml:query dp_age >= 18 | Antragsteller volljährig holds for *a case* | label: Antragsteller volljährig |
| node(3) | XOR | encoded | XOR of 2 children | Einkommensprüfung holds for *a case* | label: Einkommensprüfung |
| node(6) | leaf | encoded | ruml:query dp_state = "BY" | Wohnsitz in Bayern holds for *a case* | label: Wohnsitz in Bayern |
| node(4) | leaf | encoded | ruml:query dp_income <= 40000 | Einkommen unter Grenze holds for *a case* | label: Einkommen unter Grenze |
| node(5) | leaf | encoded | ruml:query dp_hardship = true | Härtefall anerkannt holds for *a case* | label: Härtefall anerkannt |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |
| capability(ruml:actions) | capability | residue | actions: a reaction, not a rule; the LPS companion is step 7 of the plan (delayed) |  |  |

## Residue

- **capability(ruml:actions)** (capability) — actions: a reaction, not a rule; the LPS companion is step 7 of the plan (delayed); in the program: . 

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
| generated_2 | node_1 | pass |  |
| generated_2 | not_node_1 | pass |  |
| generated_2 | node_2 | pass |  |
| generated_2 | not_node_2 | pass |  |
| generated_2 | node_3 | pass |  |
| generated_2 | not_node_3 | pass |  |
| generated_2 | node_4 | pass |  |
| generated_2 | not_node_4 | pass |  |
| generated_2 | node_5 | pass |  |
| generated_2 | not_node_5 | pass |  |
| generated_2 | node_6 | pass |  |
| generated_2 | not_node_6 | pass |  |
| generated_3 | node_1 | pass |  |
| generated_3 | not_node_1 | pass |  |
| generated_3 | node_2 | pass |  |
| generated_3 | not_node_2 | pass |  |
| generated_3 | node_3 | pass |  |
| generated_3 | not_node_3 | pass |  |
| generated_3 | node_4 | pass |  |
| generated_3 | not_node_4 | pass |  |
| generated_3 | node_5 | pass |  |
| generated_3 | not_node_5 | pass |  |
| generated_3 | node_6 | pass |  |
| generated_3 | not_node_6 | pass |  |
| generated_4 | node_1 | pass |  |
| generated_4 | not_node_1 | pass |  |
| generated_4 | node_2 | pass |  |
| generated_4 | not_node_2 | pass |  |
| generated_4 | node_3 | pass |  |
| generated_4 | not_node_3 | pass |  |
| generated_4 | node_4 | pass |  |
| generated_4 | not_node_4 | pass |  |
| generated_4 | node_5 | pass |  |
| generated_4 | not_node_5 | pass |  |
| generated_4 | node_6 | pass |  |
| generated_4 | not_node_6 | pass |  |
| generated_5 | node_1 | pass |  |
| generated_5 | not_node_1 | pass |  |
| generated_5 | node_2 | pass |  |
| generated_5 | not_node_2 | pass |  |
| generated_5 | node_3 | pass |  |
| generated_5 | not_node_3 | pass |  |
| generated_5 | node_4 | pass |  |
| generated_5 | not_node_4 | pass |  |
| generated_5 | node_5 | pass |  |
| generated_5 | not_node_5 | pass |  |
| generated_5 | node_6 | pass |  |
| generated_5 | not_node_6 | pass |  |
| generated_6 | node_1 | pass |  |
| generated_6 | not_node_1 | pass |  |
| generated_6 | node_2 | pass |  |
| generated_6 | not_node_2 | pass |  |
| generated_6 | node_3 | pass |  |
| generated_6 | not_node_3 | pass |  |
| generated_6 | node_4 | pass |  |
| generated_6 | not_node_4 | pass |  |
| generated_6 | node_5 | pass |  |
| generated_6 | not_node_5 | pass |  |
| generated_6 | node_6 | pass |  |
| generated_6 | not_node_6 | pass |  |
| generated_7 | node_1 | pass |  |
| generated_7 | not_node_1 | pass |  |
| generated_7 | node_2 | pass |  |
| generated_7 | not_node_2 | pass |  |
| generated_7 | node_3 | pass |  |
| generated_7 | not_node_3 | pass |  |
| generated_7 | node_4 | pass |  |
| generated_7 | not_node_4 | pass |  |
| generated_7 | node_5 | pass |  |
| generated_7 | not_node_5 | pass |  |
| generated_7 | node_6 | pass |  |
| generated_7 | not_node_6 | pass |  |
| generated_8 | node_1 | pass |  |
| generated_8 | not_node_1 | pass |  |
| generated_8 | node_2 | pass |  |
| generated_8 | not_node_2 | pass |  |
| generated_8 | node_3 | pass |  |
| generated_8 | not_node_3 | pass |  |
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
| generated_9 | node_3 | pass |  |
| generated_9 | not_node_3 | pass |  |
| generated_9 | node_4 | pass |  |
| generated_9 | not_node_4 | pass |  |
| generated_9 | node_5 | pass |  |
| generated_9 | not_node_5 | pass |  |
| generated_9 | node_6 | pass |  |
| generated_9 | not_node_6 | pass |  |
| generated_10 | node_1 | pass |  |
| generated_10 | not_node_1 | pass |  |
| generated_10 | node_2 | pass |  |
| generated_10 | not_node_2 | pass |  |
| generated_10 | node_3 | pass |  |
| generated_10 | not_node_3 | pass |  |
| generated_10 | node_4 | pass |  |
| generated_10 | not_node_4 | pass |  |
| generated_10 | node_5 | pass |  |
| generated_10 | not_node_5 | pass |  |
| generated_10 | node_6 | pass |  |
| generated_10 | not_node_6 | pass |  |
| generated_11 | node_1 | pass |  |
| generated_11 | not_node_1 | pass |  |
| generated_11 | node_2 | pass |  |
| generated_11 | not_node_2 | pass |  |
| generated_11 | node_3 | pass |  |
| generated_11 | not_node_3 | pass |  |
| generated_11 | node_4 | pass |  |
| generated_11 | not_node_4 | pass |  |
| generated_11 | node_5 | pass |  |
| generated_11 | not_node_5 | pass |  |
| generated_11 | node_6 | pass |  |
| generated_11 | not_node_6 | pass |  |
| generated_12 | node_1 | pass |  |
| generated_12 | not_node_1 | pass |  |
| generated_12 | node_2 | pass |  |
| generated_12 | not_node_2 | pass |  |
| generated_12 | node_3 | pass |  |
| generated_12 | not_node_3 | pass |  |
| generated_12 | node_4 | pass |  |
| generated_12 | not_node_4 | pass |  |
| generated_12 | node_5 | pass |  |
| generated_12 | not_node_5 | pass |  |
| generated_12 | node_6 | pass |  |
| generated_12 | not_node_6 | pass |  |
| generated_13 | node_1 | pass |  |
| generated_13 | not_node_1 | pass |  |
| generated_13 | node_2 | pass |  |
| generated_13 | not_node_2 | pass |  |
| generated_13 | node_3 | pass |  |
| generated_13 | not_node_3 | pass |  |
| generated_13 | node_4 | pass |  |
| generated_13 | not_node_4 | pass |  |
| generated_13 | node_5 | pass |  |
| generated_13 | not_node_5 | pass |  |
| generated_13 | node_6 | pass |  |
| generated_13 | not_node_6 | pass |  |
| generated_14 | node_1 | pass |  |
| generated_14 | not_node_1 | pass |  |
| generated_14 | node_2 | pass |  |
| generated_14 | not_node_2 | pass |  |
| generated_14 | node_3 | pass |  |
| generated_14 | not_node_3 | pass |  |
| generated_14 | node_4 | pass |  |
| generated_14 | not_node_4 | pass |  |
| generated_14 | node_5 | pass |  |
| generated_14 | not_node_5 | pass |  |
| generated_14 | node_6 | pass |  |
| generated_14 | not_node_6 | pass |  |

