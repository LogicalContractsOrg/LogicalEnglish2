# Migration ledger: 4_2_accept_custom_capability_with_role

Source: RUML — accept-custom-capability-with-role.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 2 |
| residue | 0 |
| **total** | 3 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| node(1) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Prüfung abgeschlossen holds for *a case* | RUML: undefined until decided |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |
| capability(org.ruml.test/data) | capability | approximated | a capability the twin does not use: kept in the original under sources/ |  |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |

