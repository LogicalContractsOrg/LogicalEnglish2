# Migration ledger: 4_16_company_founding

Source: RUML — company-founding.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 4 |
| approximated | 1 |
| residue | 0 |
| **total** | 5 |

Fidelity: **8 of 8** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| node(1) | AND | encoded | AND of 3 children | Company validly founded holds for *a case* |  |
| node(2) | leaf | encoded | ruml:tree-include of https://rulemapping.org/rulemapping/gmbhg:2025-01-01#node/6e51c5a6-f7ff-43e1-b211-c70bd69937d7: not available here, so the leaf is undefined, as the specification asks (§4.16) | Articles of association notarised holds for *a case* |  |
| node(3) | leaf | encoded | ruml:tree-include of https://rulemapping.org/rulemapping/gmbhg:2025-01-01#node/7791005b-3d30-455b-a538-6d96f04680d9: not available here, so the leaf is undefined, as the specification asks (§4.16) | Share capital at least eur 25000 holds for *a case* |  |
| node(4) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Entered in the commercial register holds for *a case* | RUML: undefined until decided |
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

