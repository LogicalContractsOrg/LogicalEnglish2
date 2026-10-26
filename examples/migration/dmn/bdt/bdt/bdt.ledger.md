# Migration ledger: bdt

Source: DMN — BDT.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 2 |
| **total** | 3 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| age as of date | business knowledge model | encoded | a function with a place per parameter | age as of date |  |
| invoke decision service | business knowledge model | residue | left for the assistant | r_invoke_decision_service |  |
| spouse id | business knowledge model | residue | left for the assistant | r_spouse_id |  |

## Residue

- **invoke decision service** (business knowledge model) — left for the assistant; in the program: r_invoke_decision_service. 
- **spouse id** (business knowledge model) — left for the assistant; in the program: r_spouse_id. 

