# Migration ledger: cat_smic

Source: Catala (catala-examples) — sources/cat/smic.yaml
Translator: lpsPlus migration/catala
Date: 2026-10-09
Source licence: Apache-2.0 (catala-examples, Inria and contributors)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 2 |
| approximated | 1 |
| residue | 0 |
| **total** | 3 |

Fidelity: **29 of 29** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| cat:smic#brut_horaire | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_brut_horaire | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:smic#date_courante | input | encoded | input -> a fact the scenario states | rs_date_courante |  |
| cat:smic#résidence | input | encoded | input -> a fact the scenario states | rs_résidence |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Gen1 | q_brut_horaire | pass |  |
| Gen2 | q_brut_horaire | pass |  |
| Gen3 | q_brut_horaire | pass |  |
| Gen4 | q_brut_horaire | pass |  |
| Gen5 | q_brut_horaire | pass |  |
| Gen6 | q_brut_horaire | pass |  |
| Gen7 | q_brut_horaire | pass |  |
| Gen8 | q_brut_horaire | pass |  |
| Gen9 | q_brut_horaire | pass |  |
| Gen10 | q_brut_horaire | pass |  |
| Gen11 | q_brut_horaire | pass |  |
| Gen12 | q_brut_horaire | pass |  |
| Gen13 | q_brut_horaire | pass |  |
| Gen14 | q_brut_horaire | pass |  |
| Gen15 | q_brut_horaire | pass |  |
| Gen16 | q_brut_horaire | pass |  |
| Gen17 | q_brut_horaire | pass |  |
| Gen18 | q_brut_horaire | pass |  |
| Gen19 | q_brut_horaire | pass |  |
| Gen20 | q_brut_horaire | pass |  |
| Gen21 | q_brut_horaire | pass |  |
| Gen22 | q_brut_horaire | pass |  |
| Gen23 | q_brut_horaire | pass |  |
| Gen24 | q_brut_horaire | pass |  |
| Gen25 | q_brut_horaire | pass |  |
| Gen27 | q_brut_horaire | pass |  |
| Gen28 | q_brut_horaire | pass |  |
| Gen29 | q_brut_horaire | pass |  |
| Gen30 | q_brut_horaire | pass |  |

