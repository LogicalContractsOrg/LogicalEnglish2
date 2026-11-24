# Migration ledger: 4_14_haertefall

Source: RUML — haertefall.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 10 |
| approximated | 1 |
| residue | 0 |
| **total** | 11 |

Fidelity: **168 of 168** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| dp_pflegegrad | data point | encoded | a sentence that the scenarios state | the Pflegegrad of *a case* is *a number* |  |
| dp_eigenanteil | data point | encoded | a sentence that the scenarios state | the Monatlicher Eigenanteil of *a case* is *a number* | unit: EUR |
| dp_alleinlebend | data point | encoded | a sentence that the scenarios state | the Alleinlebend of *a case* is *a truth value* |  |
| dp_wohnsitz | data point | encoded | a sentence that the scenarios state | the Wohnsitz im Land of *a case* is *a truth value* |  |
| node(1) | AND | encoded | AND of 2 children | Härtefallleistung holds for *a case* | label: Härtefallleistung |
| node(2) | DELEGATED | encoded | DELEGATED: $count($children[status = "true"]) >= 2 | Härtefall liegt vor holds for *a case* | label: Härtefall liegt vor; exact: undefined whenever a child is undefined, as the combiner contract says (§3.6.4) |
| node(7) | leaf | encoded | ruml:query dp_wohnsitz = true | Wohnsitz im Land holds for *a case* | label: Wohnsitz im Land |
| node(3) | leaf | encoded | ruml:query dp_pflegegrad >= 3 | Pflegegrad mindestens 3 holds for *a case* | label: Pflegegrad mindestens 3 |
| node(4) | leaf | encoded | ruml:query dp_eigenanteil > 800 | Eigenanteil über 800 eur holds for *a case* | label: Eigenanteil über 800 EUR |
| node(5) | leaf | encoded | ruml:query dp_alleinlebend = true | Alleinlebend holds for *a case* | label: Alleinlebend |
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
| generated_1 | node_7 | pass |  |
| generated_1 | not_node_7 | pass |  |
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
| generated_2 | node_7 | pass |  |
| generated_2 | not_node_7 | pass |  |
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
| generated_3 | node_7 | pass |  |
| generated_3 | not_node_7 | pass |  |
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
| generated_4 | node_7 | pass |  |
| generated_4 | not_node_7 | pass |  |
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
| generated_5 | node_7 | pass |  |
| generated_5 | not_node_7 | pass |  |
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
| generated_6 | node_7 | pass |  |
| generated_6 | not_node_7 | pass |  |
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
| generated_7 | node_7 | pass |  |
| generated_7 | not_node_7 | pass |  |
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
| generated_8 | node_7 | pass |  |
| generated_8 | not_node_7 | pass |  |
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
| generated_9 | node_7 | pass |  |
| generated_9 | not_node_7 | pass |  |
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
| generated_10 | node_7 | pass |  |
| generated_10 | not_node_7 | pass |  |
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
| generated_11 | node_7 | pass |  |
| generated_11 | not_node_7 | pass |  |
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
| generated_12 | node_7 | pass |  |
| generated_12 | not_node_7 | pass |  |
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
| generated_13 | node_7 | pass |  |
| generated_13 | not_node_7 | pass |  |
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
| generated_14 | node_7 | pass |  |
| generated_14 | not_node_7 | pass |  |

