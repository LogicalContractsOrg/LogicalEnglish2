# Migration ledger: cat_bmaf

Source: Catala (catala-examples) — sources/cat/bmaf.yaml
Translator: lpsPlus migration/catala
Date: 2026-10-10
Source licence: Apache-2.0 (catala-examples, Inria and contributors)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 1 |
| residue | 0 |
| **total** | 2 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| cat:bmaf#date_courante | input | encoded | input -> a fact the scenario states | rs_date_courante |  |
| cat:bmaf#montant | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_montant | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Gen1 | q_montant | pass |  |
| Gen2 | q_montant | pass |  |
| Gen3 | q_montant | pass |  |
| Gen4 | q_montant | pass |  |
| Gen5 | q_montant | pass |  |
| Gen6 | q_montant | pass |  |

