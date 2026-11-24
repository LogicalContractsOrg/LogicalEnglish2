# Migration ledger: 4_2_data_field

Source: RUML — data-field.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 3 |
| residue | 0 |
| **total** | 4 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| context(ctx_guidance) | context | approximated | context material (administrativeGuidance) | guidance | context material is listed, not reasoned with |
| dp_annual_income | data point | approximated | declared, and read by no expression: not a sentence of the twin |  | kept in the original under sources/ |
| node(1) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Anspruch auf Schadensersatz holds for *a case* | RUML: undefined until decided |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |

