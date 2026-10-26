# Migration ledger: 0100_feel_constants

Source: DMN — 0100-feel-constants.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 2 |
| approximated | 0 |
| residue | 0 |
| **total** | 2 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Decision1 | literal expression | encoded | literal expression | Decision1 |  |
| Decision2 | literal expression | encoded | literal expression | Decision2 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| t001 | q_d_decision1 | pass |  |
| t001 | q_d_decision2 | pass |  |

