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

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| context(ctx_commentary_823) | context | approximated | context material (commentary) | commentary 823 | context material is listed, not reasoned with |
| context(ctx_bgh_2024) | context | approximated | context material (courtDecision) | bgh 2024 | context material is listed, not reasoned with |
| context(ctx_palandt_823) | context | approximated | context material (commentary) | palandt 823 | context material is listed, not reasoned with |
| context(ctx_mueller_2024) | context | approximated | context material (literature) | mueller 2024 | context material is listed, not reasoned with |
| context(ctx_bmf_income_tax) | context | approximated | context material (administrativeGuidance) | bmf income tax | context material is listed, not reasoned with |
| context(ctx_historical_1950) | context | approximated | context material (history) | historical 1950 | context material is listed, not reasoned with |
| node(1) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Haftung nach § 823 bgb holds for *a case* | RUML: undefined until decided |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |

