# Migration ledger: 3_6_fiction_overrides_children

Source: RUML — fiction-overrides-children.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 5 |
| approximated | 1 |
| residue | 0 |
| **total** | 6 |

Fidelity: **32 of 32** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| dp_alter | data point | encoded | a sentence that the scenarios state | the Alter of *a case* is *a number* |  |
| node(1) | DELEGATED | encoded | DELEGATED: dp_alter >= 65 or $count($children[status = 'true']) = 3 | Voraussetzungen erfüllt oder fingiert holds for *a case* | exact: undefined whenever a child is undefined, as the combiner contract says (§3.6.4) |
| node(2) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Voraussetzung 1 holds for *a case* | RUML: undefined until decided |
| node(3) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Voraussetzung 2 holds for *a case* | RUML: undefined until decided |
| node(4) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Voraussetzung 3 holds for *a case* | RUML: undefined until decided |
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

