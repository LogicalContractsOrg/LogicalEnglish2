# Migration ledger: 4_15_articles_of_association

Source: RUML — articles-of-association.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 2 |
| approximated | 1 |
| residue | 0 |
| **total** | 3 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| node(1) | tree reference | encoded | a reference to a node of another rulemap, kept in the ledger | https://rulemapping.org/rulemapping/gmbhg:2025-01-01#node/6e51c5a6-f7ff-43e1-b211-c70bd69937d7, https://rulemapping.org/rulemapping/gmbhg:2025-01-01#node/7791005b-3d30-455b-a538-6d96f04680d9 | not evaluated, as in RUML |
| node(1) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Articles of association notarised holds for *a case* | RUML: undefined until decided |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |

