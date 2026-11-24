# Migration ledger: 4_11_context_pool

Source: RUML — context-pool.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 2 |
| approximated | 11 |
| residue | 0 |
| **total** | 13 |

Fidelity: **16 of 16** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| context(ctx_bgh_2024) | context | approximated | context material (courtDecision): BGH zur Auslegung des Wohnsitzbegriffs | bgh 2024 | context material is listed, not reasoned with |
| context(ctx_palandt_823) | context | approximated | context material (commentary): Palandt zu § 823 BGB | palandt 823 | context material is listed, not reasoned with |
| context(ctx_bmf_income_tax) | context | approximated | context material (administrativeGuidance): BMF-Schreiben zur Einkommensteuer | bmf income tax | context material is listed, not reasoned with |
| context(ctx_example_approved) | context | approximated | context material (example): Beispiel: Genehmigter Härtefall | example approved | context material is listed, not reasoned with |
| context(ctx_rulemap_residence) | context | approximated | context material (rulemap): Detailprüfung Wohnsitzbegriff | rulemap residence | context material is listed, not reasoned with |
| context(ctx_example_rejected) | context | approximated | context material (example): Beispiel: Abgelehnter Härtefall | example rejected | context material is listed, not reasoned with |
| context(ctx_bgh_judgment_pdf) | context | approximated | context material (courtDecision): BGH-Urteil I ZR 123/23 | bgh judgment pdf | context material is listed, not reasoned with |
| context(ctx_estg_32a) | context | approximated | context material (administrativeGuidance): § 32a EStG - Einkommensteuertarif | estg 32a | context material is listed, not reasoned with |
| context(ctx_internal_guidelines) | context | approximated | context material (administrativeGuidance): Interne Bearbeitungsrichtlinien | internal guidelines | context material is listed, not reasoned with |
| context(ctx_guidelines) | context | approximated | context material (administrativeGuidance): Richtlinien zur Härtefallprüfung | guidelines | context material is listed, not reasoned with |
| node(1) | AND | encoded | AND of 1 children | Härtefall anerkennen holds for *a case* | label: Härtefall anerkennen? |
| node(2) | leaf | encoded | a leaf with no deciding capability: a person's answer, a fact of the case (`the answer to ... is true`) | Einkommensgrenze unterschritten holds for *a case* | label: Einkommensgrenze unterschritten; RUML: undefined until answered |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |
| generated_1 | node_2 | pass |  |
| generated_1 | not_node_2 | pass |  |
| generated_2 | node_1 | pass |  |
| generated_2 | not_node_1 | pass |  |
| generated_2 | node_2 | pass |  |
| generated_2 | not_node_2 | pass |  |
| generated_3 | node_1 | pass |  |
| generated_3 | not_node_1 | pass |  |
| generated_3 | node_2 | pass |  |
| generated_3 | not_node_2 | pass |  |
| generated_4 | node_1 | pass |  |
| generated_4 | not_node_1 | pass |  |
| generated_4 | node_2 | pass |  |
| generated_4 | not_node_2 | pass |  |

