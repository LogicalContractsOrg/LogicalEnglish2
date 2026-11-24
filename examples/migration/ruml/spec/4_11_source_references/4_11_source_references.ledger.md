# Migration ledger: 4_11_source_references

Source: RUML — source-references.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 7 |
| residue | 0 |
| **total** | 8 |

Fidelity: **8 of 8** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| context(ctx_commentary_823) | context | approximated | context material (commentary): Kommentar zu § 823 BGB | commentary 823 | context material is listed, not reasoned with |
| context(ctx_bgh_2024) | context | approximated | context material (courtDecision): BGH zur Auslegung des Wohnsitzbegriffs | bgh 2024 | context material is listed, not reasoned with |
| context(ctx_palandt_823) | context | approximated | context material (commentary): Palandt zu § 823 BGB | palandt 823 | context material is listed, not reasoned with |
| context(ctx_mueller_2024) | context | approximated | context material (literature): Müller, Digitale Verwaltung | mueller 2024 | context material is listed, not reasoned with |
| context(ctx_bmf_income_tax) | context | approximated | context material (administrativeGuidance): BMF-Schreiben zur Einkommensteuer | bmf income tax | context material is listed, not reasoned with |
| context(ctx_historical_1950) | context | approximated | context material (history): Historisches Dokument von 1950 | historical 1950 | context material is listed, not reasoned with |
| node(1) | leaf | encoded | a leaf with no deciding capability: a person's answer, a fact of the case (`the answer to ... is true`) | Haftung nach § 823 bgb holds for *a case* | label: Haftung nach § 823 BGB; RUML: undefined until answered |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |
| generated_2 | node_1 | pass |  |
| generated_2 | not_node_1 | pass |  |
| generated_3 | node_1 | pass |  |
| generated_3 | not_node_1 | pass |  |
| generated_4 | node_1 | pass |  |
| generated_4 | not_node_1 | pass |  |

