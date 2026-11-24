# Migration ledger: 4_14_hardship_with_text_and_action

Source: RUML — hardship-with-text-and-action.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 6 |
| approximated | 1 |
| residue | 1 |
| **total** | 8 |

Fidelity: **10 of 10** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| text(text_sgb_xii_90) | text | encoded | a document of the twin (a text named by its address) | sgb xii 90 | § 90 SGB XII |
| node(1) | AND | encoded | AND of 1 children | Härtefallleistung holds for *a case* |  |
| node(2) | DELEGATED | encoded | DELEGATED: $count($children[status = "true"]) >= 2 | Härtefall liegt vor holds for *a case* | exact: undefined whenever a child is undefined, as the combiner contract says (§3.6.4) |
| node(4) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Pflegegrad mindestens 3 holds for *a case* | RUML: undefined until decided |
| node(5) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Eigenanteil über 800 eur holds for *a case* | RUML: undefined until decided |
| node(6) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Alleinlebend holds for *a case* | RUML: undefined until decided |
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
| generated_1 | node_4 | pass |  |
| generated_1 | not_node_4 | pass |  |
| generated_1 | node_5 | pass |  |
| generated_1 | not_node_5 | pass |  |
| generated_1 | node_6 | pass |  |
| generated_1 | not_node_6 | pass |  |

