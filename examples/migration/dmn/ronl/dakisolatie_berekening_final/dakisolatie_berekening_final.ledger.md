# Migration ledger: dakisolatie_berekening_final

Source: DMN — dakisolatie-berekening-final.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 0 |
| **total** | 1 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Bereken Isolatie Opties | decision table | encoded | decision table | Bereken Isolatie Opties | a rule per row |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| g001 | q_d_rel_bereken_isolatie_opties | pass |  |
| g003 | q_d_rel_bereken_isolatie_opties | pass |  |

