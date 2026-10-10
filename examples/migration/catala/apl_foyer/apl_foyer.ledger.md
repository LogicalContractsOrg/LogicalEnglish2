# Migration ledger: cat_apl_foyer

Source: Catala (catala-examples) — sources/cat/apl_foyer.yaml
Translator: lpsPlus migration/catala
Date: 2026-10-10
Source licence: Apache-2.0 (catala-examples, Inria and contributors)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 41 |
| approximated | 1 |
| residue | 3 |
| **total** | 45 |

Fidelity: **14 of 14** source test expectation(s) reproduced (100%).

**4 further expectation(s) are pending** (waits for residue r1): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| cat:apl_foyer#aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_aide_finale_formule_initiale |  |
| cat:apl_foyer#calcul_nombre_parts_condition_2_du_832_25 | derived | encoded | derived judgment -> a rule concluding a sentence | rs_calcul_nombre_parts_condition_2_du_832_25 |  |
| cat:apl_foyer#calcul_nombre_parts_date_courante | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_nombre_parts_date_courante |  |
| cat:apl_foyer#calcul_nombre_parts_limitation_majoration_personnes_à_charge | derived | encoded | derived judgment -> a rule concluding a sentence | rs_calcul_nombre_parts_limitation_majoration_personnes_à_charge |  |
| cat:apl_foyer#calcul_nombre_parts_n_nombre_parts_d832_25 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_nombre_parts_n_nombre_parts_d832_25 |  |
| cat:apl_foyer#calcul_nombre_parts_n_nombre_parts_d832_25_base | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_nombre_parts_n_nombre_parts_d832_25_base |  |
| cat:apl_foyer#calcul_nombre_parts_n_nombre_parts_d832_25_majoration | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_nombre_parts_n_nombre_parts_d832_25_majoration |  |
| cat:apl_foyer#calcul_nombre_parts_nombre_personnes_à_charge | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_nombre_parts_nombre_personnes_à_charge |  |
| cat:apl_foyer#calcul_nombre_parts_situation_familiale_calcul_apl | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_nombre_parts_situation_familiale_calcul_apl |  |
| cat:apl_foyer#calcul_équivalence_loyer_minimale_condition_2_du_832_25 | derived | encoded | derived judgment -> a rule concluding a sentence | rs_calcul_équivalence_loyer_minimale_condition_2_du_832_25 |  |
| cat:apl_foyer#calcul_équivalence_loyer_minimale_date_courante | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_équivalence_loyer_minimale_date_courante |  |
| cat:apl_foyer#calcul_équivalence_loyer_minimale_montant | derived | residue | residue block r1 with the rule's YAML | rs_calcul_équivalence_loyer_minimale_montant |  |
| cat:apl_foyer#calcul_équivalence_loyer_minimale_montant_forfaitaire_d832_26 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_équivalence_loyer_minimale_montant_forfaitaire_d832_26 |  |
| cat:apl_foyer#calcul_équivalence_loyer_minimale_n_nombre_parts_d832_25 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_équivalence_loyer_minimale_n_nombre_parts_d832_25 |  |
| cat:apl_foyer#calcul_équivalence_loyer_minimale_ressources_ménage_arrondies | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_équivalence_loyer_minimale_ressources_ménage_arrondies |  |
| cat:apl_foyer#coefficient_multiplicateur_d832_25 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_coefficient_multiplicateur_d832_25 |  |
| cat:apl_foyer#coefficient_prise_en_charge_d832_25 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_coefficient_prise_en_charge_d832_25 |  |
| cat:apl_foyer#coefficient_prise_en_charge_d832_25_coeff_arrondi | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_coefficient_prise_en_charge_d832_25_coeff_arrondi |  |
| cat:apl_foyer#coefficient_prise_en_charge_d832_25_formule | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_coefficient_prise_en_charge_d832_25_formule |  |
| cat:apl_foyer#coefficient_r_d832_25 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_coefficient_r_d832_25 |  |
| cat:apl_foyer#condition_2_du_832_25 | derived | encoded | derived judgment -> a rule concluding a sentence | rs_condition_2_du_832_25 |  |
| cat:apl_foyer#contributions_sociales_date_courante | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_contributions_sociales_date_courante |  |
| cat:apl_foyer#contributions_sociales_exonéré_csg | derived | encoded | derived judgment -> a rule concluding a sentence | rs_contributions_sociales_exonéré_csg |  |
| cat:apl_foyer#contributions_sociales_lieu | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_contributions_sociales_lieu |  |
| cat:apl_foyer#contributions_sociales_taux_crds | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_contributions_sociales_taux_crds |  |
| cat:apl_foyer#date_conventionnement | input | encoded | input -> a fact the scenario states | rs_date_conventionnement |  |
| cat:apl_foyer#date_courante | input | encoded | input -> a fact the scenario states | rs_date_courante |  |
| cat:apl_foyer#is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26 | derived | residue | residue block r2 with the rule's YAML | rs_is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26 |  |
| cat:apl_foyer#is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26_multipliées | derived | residue | residue block r3 with the rule's YAML | rs_is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26_multipliées |  |
| cat:apl_foyer#limitation_majoration_personnes_à_charge | derived | encoded | derived judgment -> a rule concluding a sentence | rs_limitation_majoration_personnes_à_charge |  |
| cat:apl_foyer#logement_foyer_jeunes_travailleurs | input | encoded | input -> a fact the scenario states | rs_logement_foyer_jeunes_travailleurs |  |
| cat:apl_foyer#montant_forfaitaire_d832_24 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_montant_forfaitaire_d832_24 |  |
| cat:apl_foyer#montant_forfaitaire_d832_27 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_montant_forfaitaire_d832_27 |  |
| cat:apl_foyer#montant_minimal_aide_d823_24 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_montant_minimal_aide_d823_24 |  |
| cat:apl_foyer#n_nombre_parts_d832_25 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_n_nombre_parts_d832_25 |  |
| cat:apl_foyer#nombre_personnes_à_charge | input | encoded | input -> a fact the scenario states | rs_nombre_personnes_à_charge |  |
| cat:apl_foyer#plafond_équivalence_loyer_éligible | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_plafond_équivalence_loyer_éligible | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_foyer#redevance | input | encoded | input -> a fact the scenario states | rs_redevance |  |
| cat:apl_foyer#ressources_ménage_arrondies | input | encoded | input -> a fact the scenario states | rs_ressources_ménage_arrondies |  |
| cat:apl_foyer#résidence | input | encoded | input -> a fact the scenario states | rs_résidence |  |
| cat:apl_foyer#situation_familiale_calcul_apl | input | encoded | input -> a fact the scenario states | rs_situation_familiale_calcul_apl |  |
| cat:apl_foyer#type_logement_foyer | input | encoded | input -> a fact the scenario states | rs_type_logement_foyer |  |
| cat:apl_foyer#zone | input | encoded | input -> a fact the scenario states | rs_zone |  |
| cat:apl_foyer#équivalence_loyer_minimale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_équivalence_loyer_minimale |  |
| cat:apl_foyer#équivalence_loyer_éligible | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_équivalence_loyer_éligible |  |

## Residue

- **cat:apl_foyer#calcul_équivalence_loyer_minimale_montant** (derived) — residue block r1 with the rule's YAML; in the program: rs_calcul_équivalence_loyer_minimale_montant. 
- **cat:apl_foyer#is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26** (derived) — residue block r2 with the rule's YAML; in the program: rs_is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26. 
- **cat:apl_foyer#is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26_multipliées** (derived) — residue block r3 with the rule's YAML; in the program: rs_is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26_multipliées. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| CasTest1 | q_coefficient_multiplicateur_d832_25 | pass |  |
| CasTest1 | q_coefficient_prise_en_charge_d832_25 | pass |  |
| CasTest1 | q_coefficient_r_d832_25 | pass |  |
| CasTest1 | q_n_nombre_parts_d832_25 | pass |  |
| CasTest1 | q_plafond_équivalence_loyer_éligible | pass |  |
| CasTest3 | q_coefficient_prise_en_charge_d832_25 | pass |  |
| CasTest3 | q_plafond_équivalence_loyer_éligible | pass |  |
| CasTest3 | q_équivalence_loyer_éligible | pass |  |
| CasTest4 | q_coefficient_prise_en_charge_d832_25 | pass |  |
| CasTest4 | q_plafond_équivalence_loyer_éligible | pass |  |
| CasTest4 | q_équivalence_loyer_éligible | pass |  |
| CasTest5 | q_coefficient_prise_en_charge_d832_25 | pass |  |
| CasTest5 | q_plafond_équivalence_loyer_éligible | pass |  |
| CasTest5 | q_équivalence_loyer_éligible | pass |  |

