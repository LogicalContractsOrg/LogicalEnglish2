# Migration ledger: cat_prestations_familiales

Source: Catala (catala-examples) — sources/cat/prestations_familiales.yaml
Translator: lpsPlus migration/catala
Date: 2026-10-07
Source licence: Apache-2.0 (catala-examples, Inria and contributors)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 11 |
| approximated | 2 |
| residue | 0 |
| **total** | 13 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| cat:prestations_familiales#conditions_hors_âge | derived | encoded | derived judgment -> a rule concluding a sentence | rs_conditions_hors_âge |  |
| cat:prestations_familiales#date_courante | input | encoded | input -> a fact the scenario states | rs_date_courante |  |
| cat:prestations_familiales#date_de_naissance | input | encoded | input -> a fact the scenario states | rs_date_de_naissance |  |
| cat:prestations_familiales#droit_ouvert | derived | approximated | derived judgment -> a rule concluding a sentence | rs_droit_ouvert | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:prestations_familiales#obligation_scolaire | input | encoded | input -> a fact the scenario states | rs_obligation_scolaire |  |
| cat:prestations_familiales#plafond_l512_3_2 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_plafond_l512_3_2 |  |
| cat:prestations_familiales#régime_outre_mer_l751_1 | derived | encoded | derived judgment -> a rule concluding a sentence | rs_régime_outre_mer_l751_1 |  |
| cat:prestations_familiales#rémuneration_mensuelle | input | encoded | input -> a fact the scenario states | rs_rémuneration_mensuelle |  |
| cat:prestations_familiales#résidence | input | encoded | input -> a fact the scenario states | rs_résidence |  |
| cat:prestations_familiales#smic_brut_horaire | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_smic_brut_horaire | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:prestations_familiales#smic_date_courante | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_smic_date_courante |  |
| cat:prestations_familiales#smic_résidence | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_smic_résidence |  |
| cat:prestations_familiales#âge_l512_3_2 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_âge_l512_3_2 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Test1_droit_ouvert_enfant1 | q_droit_ouvert | pass |  |
| Test1_droit_ouvert_enfant2 | q_droit_ouvert | pass |  |
| Test1_droit_ouvert_enfant3 | q_droit_ouvert | pass |  |
| Test1_droit_ouvert_enfant4 | q_droit_ouvert | pass |  |

