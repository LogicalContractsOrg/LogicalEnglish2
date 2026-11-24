# Migration ledger: 4_7_bindings

Source: RUML — bindings.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 4 |
| approximated | 4 |
| residue | 0 |
| **total** | 8 |

Fidelity: **10 of 10** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| dp_annual_income | data point | approximated | declared, and read by no expression: not a sentence of the twin |  | kept in the original under sources/ |
| dp_gross_annual_income | data point | approximated | declared, and read by no expression: not a sentence of the twin |  | kept in the original under sources/ |
| dp_credit_score | data point | approximated | declared, and read by no expression: not a sentence of the twin |  | kept in the original under sources/ |
| dp_zve | data point | encoded | a sentence that the scenarios state | the Zu versteuerndes Einkommen of *a case* is *a number* | unit: EUR |
| dp_einkommensteuer | data point | encoded | a sentence that the scenarios state | the Festzusetzende Einkommensteuer of *a case* is *a number* | unit: EUR |
| dp_einkommensteuer | computed data point | encoded | a computed data point: (dp_zve - 11604) * 0.14 | the Festzusetzende Einkommensteuer of *a case* |  |
| node(1) | leaf | encoded | a leaf with no deciding capability: a person's answer, a fact of the case (`the answer to ... is true`) | Kredit wird gewährt holds for *a case* | label: Kredit wird gewährt; RUML: undefined until answered |
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
| generated_5 | node_1 | pass |  |
| generated_5 | not_node_1 | pass |  |

