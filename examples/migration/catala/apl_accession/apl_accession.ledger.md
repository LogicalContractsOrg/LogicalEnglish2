# Migration ledger: cat_apl_accession

Source: Catala (catala-examples) — sources/cat/apl_accession.yaml
Translator: lpsPlus migration/catala
Date: 2026-10-10
Source licence: Apache-2.0 (catala-examples, Inria and contributors)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 45 |
| approximated | 5 |
| residue | 3 |
| **total** | 53 |

Fidelity: **6 of 8** source test expectation(s) reproduced (75%); 2 fail, 0 could not be run.

**8 further expectation(s) are pending** (waits for residue r1): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| cat:apl_accession#aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_aide_finale_formule_initiale |  |
| cat:apl_accession#ancienneté_logement | input | encoded | input -> a fact the scenario states | rs_ancienneté_logement |  |
| cat:apl_accession#ancienneté_logement_Ancien | input | encoded | input -> a fact the scenario states | rs_ancienneté_logement_Ancien |  |
| cat:apl_accession#calcul_nombre_parts_n_nombre_parts_d832_11 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_nombre_parts_n_nombre_parts_d832_11 |  |
| cat:apl_accession#calcul_nombre_parts_nombre_personnes_à_charge | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_nombre_parts_nombre_personnes_à_charge |  |
| cat:apl_accession#calcul_nombre_parts_situation_familiale_calcul_apl | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_nombre_parts_situation_familiale_calcul_apl |  |
| cat:apl_accession#calcul_plafond_mensualité_d832_10_3_de_date_entrée_logement | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_plafond_mensualité_d832_10_3_de_date_entrée_logement | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_accession#calcul_plafond_mensualité_d832_10_3_de_date_signature_prêt | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_plafond_mensualité_d832_10_3_de_date_signature_prêt | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_accession#calcul_équivalence_loyer_minimale_condition_2_du_832_25 | derived | encoded | derived judgment -> a rule concluding a sentence | rs_calcul_équivalence_loyer_minimale_condition_2_du_832_25 |  |
| cat:apl_accession#calcul_équivalence_loyer_minimale_date_courante | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_équivalence_loyer_minimale_date_courante |  |
| cat:apl_accession#calcul_équivalence_loyer_minimale_montant | derived | residue | residue block r1 with the rule's YAML | rs_calcul_équivalence_loyer_minimale_montant |  |
| cat:apl_accession#calcul_équivalence_loyer_minimale_montant_forfaitaire_d832_26 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_équivalence_loyer_minimale_montant_forfaitaire_d832_26 |  |
| cat:apl_accession#calcul_équivalence_loyer_minimale_n_nombre_parts_d832_25 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_équivalence_loyer_minimale_n_nombre_parts_d832_25 |  |
| cat:apl_accession#calcul_équivalence_loyer_minimale_ressources_ménage_arrondies | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_équivalence_loyer_minimale_ressources_ménage_arrondies |  |
| cat:apl_accession#coefficient_multiplicateur_d832_11 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_coefficient_multiplicateur_d832_11 |  |
| cat:apl_accession#coefficient_multiplicateur_d832_17_3 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_coefficient_multiplicateur_d832_17_3 |  |
| cat:apl_accession#coefficient_multiplicateur_d832_18 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_coefficient_multiplicateur_d832_18 |  |
| cat:apl_accession#coefficient_prise_en_charge_d832_10 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_coefficient_prise_en_charge_d832_10 |  |
| cat:apl_accession#coefficient_prise_en_charge_d832_10_coeff_arrondi | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_coefficient_prise_en_charge_d832_10_coeff_arrondi |  |
| cat:apl_accession#coefficient_prise_en_charge_d832_10_formule | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_coefficient_prise_en_charge_d832_10_formule |  |
| cat:apl_accession#contributions_sociales_date_courante | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_contributions_sociales_date_courante |  |
| cat:apl_accession#contributions_sociales_exonéré_csg | derived | encoded | derived judgment -> a rule concluding a sentence | rs_contributions_sociales_exonéré_csg |  |
| cat:apl_accession#contributions_sociales_lieu | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_contributions_sociales_lieu |  |
| cat:apl_accession#contributions_sociales_taux_crds | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_contributions_sociales_taux_crds |  |
| cat:apl_accession#copropriété | input | encoded | input -> a fact the scenario states | rs_copropriété |  |
| cat:apl_accession#date_courante | input | encoded | input -> a fact the scenario states | rs_date_courante |  |
| cat:apl_accession#date_entrée_logement | input | encoded | input -> a fact the scenario states | rs_date_entrée_logement |  |
| cat:apl_accession#date_signature_prêt | input | encoded | input -> a fact the scenario states | rs_date_signature_prêt |  |
| cat:apl_accession#is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26 | derived | residue | residue block r2 with the rule's YAML | rs_is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26 |  |
| cat:apl_accession#is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26_multipliées | derived | residue | residue block r3 with the rule's YAML | rs_is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26_multipliées |  |
| cat:apl_accession#local_habité_première_fois_bénéficiaire | input | encoded | input -> a fact the scenario states | rs_local_habité_première_fois_bénéficiaire |  |
| cat:apl_accession#mensualité_minimale | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_mensualité_minimale | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_accession#mensualité_principale | input | encoded | input -> a fact the scenario states | rs_mensualité_principale |  |
| cat:apl_accession#mensualité_éligible | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_mensualité_éligible |  |
| cat:apl_accession#montant_forfaitaire_charges_d832_10 | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_montant_forfaitaire_charges_d832_10 | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_accession#montant_forfaitaire_d832_10 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_montant_forfaitaire_d832_10 |  |
| cat:apl_accession#montant_limite_tranches_d832_15_1 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_montant_limite_tranches_d832_15_1 |  |
| cat:apl_accession#montant_minimal_aide_d832_10 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_montant_minimal_aide_d832_10 |  |
| cat:apl_accession#n_nombre_parts_d832_11 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_n_nombre_parts_d832_11 |  |
| cat:apl_accession#nombre_personnes_à_charge | input | encoded | input -> a fact the scenario states | rs_nombre_personnes_à_charge |  |
| cat:apl_accession#plafond_mensualité_d832_10_3 | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_plafond_mensualité_d832_10_3 | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_accession#plafond_mensualité_d832_10_3_base | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_plafond_mensualité_d832_10_3_base |  |
| cat:apl_accession#ressources_ménage_arrondies | input | encoded | input -> a fact the scenario states | rs_ressources_ménage_arrondies |  |
| cat:apl_accession#ressources_ménage_avec_d832_18 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_ressources_ménage_avec_d832_18 |  |
| cat:apl_accession#résidence | input | encoded | input -> a fact the scenario states | rs_résidence |  |
| cat:apl_accession#situation_familiale_calcul_apl | input | encoded | input -> a fact the scenario states | rs_situation_familiale_calcul_apl |  |
| cat:apl_accession#situation_r822_11_13_17 | input | encoded | input -> a fact the scenario states | rs_situation_r822_11_13_17 |  |
| cat:apl_accession#taux_francs_vers_euros | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_taux_francs_vers_euros |  |
| cat:apl_accession#taux_tranche_inférieure_d832_15_1 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_taux_tranche_inférieure_d832_15_1 |  |
| cat:apl_accession#taux_tranche_supérieure_d832_15_1 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_taux_tranche_supérieure_d832_15_1 |  |
| cat:apl_accession#type_prêt | input | encoded | input -> a fact the scenario states | rs_type_prêt |  |
| cat:apl_accession#type_travaux_logement | input | encoded | input -> a fact the scenario states | rs_type_travaux_logement |  |
| cat:apl_accession#zone | input | encoded | input -> a fact the scenario states | rs_zone |  |

## Residue

- **cat:apl_accession#calcul_équivalence_loyer_minimale_montant** (derived) — residue block r1 with the rule's YAML; in the program: rs_calcul_équivalence_loyer_minimale_montant. 
- **cat:apl_accession#is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26** (derived) — residue block r2 with the rule's YAML; in the program: rs_is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26. 
- **cat:apl_accession#is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26_multipliées** (derived) — residue block r3 with the rule's YAML; in the program: rs_is_in_calcul_équivalence_loyer_minimale_tranches_revenus_d832_26_multipliées. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Exemple1 | q_coefficient_prise_en_charge_d832_10 | pass |  |
| Exemple1 | q_mensualité_éligible | pass |  |
| Exemple2 | q_coefficient_prise_en_charge_d832_10 | pass |  |
| Exemple2 | q_mensualité_éligible | fail | expected [la mensualité éligible est 399,2], got [la mensualité éligible est 300,47701297493586] |
| Exemple3 | q_coefficient_prise_en_charge_d832_10 | pass |  |
| Exemple3 | q_mensualité_éligible | pass |  |
| Exemple4 | q_coefficient_prise_en_charge_d832_10 | pass |  |
| Exemple4 | q_mensualité_éligible | fail | expected [la mensualité éligible est 399,2], got [la mensualité éligible est 300,47701297493586] |

