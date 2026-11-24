# Migration ledger: 4_7_data_types

Source: RUML — data-types.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 8 |
| residue | 0 |
| **total** | 9 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| dp_residence | data point | approximated | declared, and read by no expression: not a sentence of the twin |  | kept in the original under sources/ |
| dp_jurisdiction | data point | approximated | declared, and read by no expression: not a sentence of the twin |  | kept in the original under sources/ |
| dp_residence_address | data point | approximated | declared, and read by no expression: not a sentence of the twin |  | kept in the original under sources/ |
| dp_tax_id | data point | approximated | declared, and read by no expression: not a sentence of the twin |  | kept in the original under sources/ |
| dp_marital_status | data point | approximated | declared, and read by no expression: not a sentence of the twin |  | kept in the original under sources/ |
| dp_loan_amount | data point | approximated | declared, and read by no expression: not a sentence of the twin |  | kept in the original under sources/ |
| dp_children_count | data point | approximated | declared, and read by no expression: not a sentence of the twin |  | kept in the original under sources/ |
| node(1) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Antrag ist zulässig holds for *a case* | RUML: undefined until decided |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |

