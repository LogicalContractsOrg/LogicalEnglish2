# Migration ledger: 4_12_text_entries

Source: RUML — text-entries.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 4 |
| approximated | 1 |
| residue | 0 |
| **total** | 5 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| text(text_main) | text | encoded | a document of the twin (a law carried as Akoma Ntoso) | main | Sozialgesetzbuch (SGB) Zwölftes Buch (XII) – Sozialhilfe |
| text(text_bgb_823) | text | encoded | a document of the twin (a text carried in the file) | bgb 823 | § 823 BGB – Schadensersatzpflicht |
| text(text_3f2c9a1e4b7d4e0f9a6c1b2d3e4f5a6b) | text | encoded | a document of the twin (a law carried as Akoma Ntoso) | text 3f2c9a1e4b7d4e0f9a6c1b2d3e4f5a6b | Benutzungssatzung der Stadtbibliothek |
| node(1) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Aufgabe der Sozialhilfe holds for *a case* | RUML: undefined until decided |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |

