# Migration ledger: 4_9_hardship_plausibility_check

Source: RUML — hardship-plausibility-check.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 4 |
| approximated | 8 |
| residue | 1 |
| **total** | 13 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| text(text_bgb_823) | text | encoded | a document of the twin (a text carried in the file) | bgb 823 | § 823 BGB – Schadensersatzpflicht |
| context(ctx_guidelines) | context | approximated | context material (administrativeGuidance): Richtlinien zur Härtefallprüfung | guidelines | context material is listed, not reasoned with |
| context(ctx_gutachten) | context | approximated | context material (custom): Ärztliches Gutachten der Antragstellerin | gutachten | context material is listed, not reasoned with |
| context(ctx_bsg_ruling) | context | approximated | context material (courtDecision): BSG zur Auslegung des Härtefallbegriffs | bsg ruling | context material is listed, not reasoned with |
| context(ctx_example_approved_medical) | context | approximated | context material (example): Beispiel: Genehmigt - Medizinische Notlage | example approved medical | context material is listed, not reasoned with |
| context(ctx_example_rejected_luxury) | context | approximated | context material (example): Beispiel: Abgelehnt - Freiwillige Ausgaben | example rejected luxury | context material is listed, not reasoned with |
| dp_hardship_reason | data point | approximated | declared, and read by no expression: not a sentence of the twin |  | kept in the original under sources/ |
| dp_annual_income | data point | approximated | declared, and read by no expression: not a sentence of the twin |  | kept in the original under sources/ |
| node(1) | AND | encoded | AND of 2 children | Härtefall anerkennen holds for *a case* | label: Härtefall anerkennen? |
| node(2) | leaf | encoded | ruml:ai-query: a judged sentence (the prompt: Prüfe anhand der bereitgestellten Unterlagen, ob eine Härtefallbegründung plausibel ist. Antworte ausschließlich mit true, false oder undefined.) | Begründung laut Gutachten plausibel holds for *a case* | label: Begründung laut Gutachten plausibel |
| node(3) | leaf | encoded | ruml:ai-query: a judged sentence (the prompt: Prüfe anhand der bereitgestellten Unterlagen, ob eine Härtefallbegründung plausibel ist. Antworte ausschließlich mit true, false oder undefined.) | Begründung plausibel holds for *a case* | label: Begründung plausibel |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |
| capability(ruml:actions) | capability | residue | actions: a reaction, not a rule; the LPS companion is step 7 of the plan (delayed) |  |  |

## Residue

- **capability(ruml:actions)** (capability) — actions: a reaction, not a rule; the LPS companion is step 7 of the plan (delayed); in the program: . 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |
| generated_1 | node_2 | pass |  |
| generated_1 | not_node_2 | pass |  |
| generated_1 | node_3 | pass |  |
| generated_1 | not_node_3 | pass |  |

