# Migration ledger: 4_10_notice_creation

Source: RUML — notice-creation.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 2 |
| approximated | 1 |
| residue | 1 |
| **total** | 4 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| dp_application_complete | data point | encoded | a sentence that the scenarios state | the Antrag vollständig of *a case* is *a truth value* |  |
| node(1) | leaf | encoded | ruml:query dp_application_complete = true | Bescheiderstellung holds for *a case* | label: Bescheiderstellung |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |
| capability(ruml:actions) | capability | residue | actions: a reaction, not a rule; the LPS companion is step 7 of the plan (delayed) |  |  |

## Residue

- **capability(ruml:actions)** (capability) — actions: a reaction, not a rule; the LPS companion is step 7 of the plan (delayed); in the program: . 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |
| generated_2 | node_1 | pass |  |
| generated_2 | not_node_1 | pass |  |
| generated_3 | node_1 | pass |  |
| generated_3 | not_node_1 | pass |  |

