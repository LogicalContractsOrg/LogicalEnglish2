# Migration ledger: gedelegeerd_besluit_route

Source: DMN — gedelegeerd-besluit-route.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 0 |
| approximated | 1 |
| residue | 0 |
| **total** | 1 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Route besluit onder gedelegeerde bevoegdheid | decision table | approximated | decision table | Route besluit onder gedelegeerde bevoegdheid | a column that compares numbers and has `-` cells: where its input is null the table has no answer, while DMN matches a row with `-` |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| g001 | q_d_route_besluit_onder_gedelegeerde_bevoegdheid | pass |  |
| g002 | q_d_route_besluit_onder_gedelegeerde_bevoegdheid | pass |  |
| g003 | q_d_route_besluit_onder_gedelegeerde_bevoegdheid | pass |  |
| g004 | q_d_route_besluit_onder_gedelegeerde_bevoegdheid | pass |  |
| g005 | q_d_route_besluit_onder_gedelegeerde_bevoegdheid | pass |  |
| g006 | q_d_route_besluit_onder_gedelegeerde_bevoegdheid | pass |  |

