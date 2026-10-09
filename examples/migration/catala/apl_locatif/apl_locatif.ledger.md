# Migration ledger: cat_apl_locatif

Source: Catala (catala-examples) — sources/cat/apl_locatif.yaml
Translator: lpsPlus migration/catala
Date: 2026-10-09
Source licence: Apache-2.0 (catala-examples, Inria and contributors)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 37 |
| approximated | 13 |
| residue | 0 |
| **total** | 50 |

Fidelity: **49 of 49** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| cat:apl_locatif#abattement_forfaitaire_d823_17 | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_abattement_forfaitaire_d823_17 | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_locatif#aide_finale_après_traitement | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_aide_finale_après_traitement |  |
| cat:apl_locatif#aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_aide_finale_formule_initiale |  |
| cat:apl_locatif#bénéficiaire_aide_adulte_ou_enfant_handicapés | input | encoded | input -> a fact the scenario states | rs_bénéficiaire_aide_adulte_ou_enfant_handicapés |  |
| cat:apl_locatif#colocation | input | encoded | input -> a fact the scenario states | rs_colocation |  |
| cat:apl_locatif#contributions_sociales_date_courante | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_contributions_sociales_date_courante |  |
| cat:apl_locatif#contributions_sociales_exonéré_csg | derived | encoded | derived judgment -> a rule concluding a sentence | rs_contributions_sociales_exonéré_csg |  |
| cat:apl_locatif#contributions_sociales_lieu | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_contributions_sociales_lieu |  |
| cat:apl_locatif#contributions_sociales_montant_de_valeur_112 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_contributions_sociales_montant_de_valeur_112 |  |
| cat:apl_locatif#contributions_sociales_montant_de_valeur_7375 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_contributions_sociales_montant_de_valeur_7375 |  |
| cat:apl_locatif#contributions_sociales_taux_crds | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_contributions_sociales_taux_crds |  |
| cat:apl_locatif#date_courante | input | encoded | input -> a fact the scenario states | rs_date_courante |  |
| cat:apl_locatif#fraction_l832_3 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_fraction_l832_3 |  |
| cat:apl_locatif#logement_est_chambre | input | encoded | input -> a fact the scenario states | rs_logement_est_chambre |  |
| cat:apl_locatif#logement_meublé_d842_2 | input | encoded | input -> a fact the scenario states | rs_logement_meublé_d842_2 |  |
| cat:apl_locatif#loyer_principal | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_loyer_principal |  |
| cat:apl_locatif#loyer_principal_base | input | encoded | input -> a fact the scenario states | rs_loyer_principal_base |  |
| cat:apl_locatif#loyer_référence | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_loyer_référence | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_locatif#loyer_éligible | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_loyer_éligible |  |
| cat:apl_locatif#montant_forfaitaire_charges_d823_16 | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_montant_forfaitaire_charges_d823_16 | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_locatif#montant_forfaitaire_d823_16 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_montant_forfaitaire_d823_16 |  |
| cat:apl_locatif#montant_minimal_aide_d823_16 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_montant_minimal_aide_d823_16 |  |
| cat:apl_locatif#multiplicateur_majoration_charges_d823_16 | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_multiplicateur_majoration_charges_d823_16 | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_locatif#multiplicateur_majoration_loyer_référence | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_multiplicateur_majoration_loyer_référence | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_locatif#multiplicateur_majoration_plafond_loyer_d823_16_2 | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_multiplicateur_majoration_plafond_loyer_d823_16_2 | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_locatif#multiplicateur_majoration_r0 | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_multiplicateur_majoration_r0 | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_locatif#nombre_personnes_à_charge | input | encoded | input -> a fact the scenario states | rs_nombre_personnes_à_charge |  |
| cat:apl_locatif#participation_minimale | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_participation_minimale | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_locatif#participation_personnelle | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_participation_personnelle |  |
| cat:apl_locatif#plafond_dégressivité_d823_16 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_plafond_dégressivité_d823_16 |  |
| cat:apl_locatif#plafond_loyer_d823_16_2 | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_plafond_loyer_d823_16_2 | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_locatif#plafond_suppression_d823_16 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_plafond_suppression_d823_16 |  |
| cat:apl_locatif#rapport_loyers | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_rapport_loyers | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_locatif#ressources_ménage_arrondies | input | encoded | input -> a fact the scenario states | rs_ressources_ménage_arrondies |  |
| cat:apl_locatif#réduction_loyer_solidarité | input | encoded | input -> a fact the scenario states | rs_réduction_loyer_solidarité |  |
| cat:apl_locatif#résidence | input | encoded | input -> a fact the scenario states | rs_résidence |  |
| cat:apl_locatif#situation_familiale_calcul_apl | input | encoded | input -> a fact the scenario states | rs_situation_familiale_calcul_apl |  |
| cat:apl_locatif#taux_composition_familiale | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_taux_composition_familiale | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_locatif#taux_loyer_éligible | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_taux_loyer_éligible | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_locatif#taux_loyer_éligible_formule | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_taux_loyer_éligible_formule | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:apl_locatif#taux_prise_compte_ressources | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_taux_prise_compte_ressources |  |
| cat:apl_locatif#traitement_aide_finale_contributions_sociales_arrondi_de_aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_traitement_aide_finale_contributions_sociales_arrondi_de_aide_finale_formule_initiale |  |
| cat:apl_locatif#traitement_aide_finale_de_aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_traitement_aide_finale_de_aide_finale_formule_initiale |  |
| cat:apl_locatif#traitement_aide_finale_diminué_de_aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_traitement_aide_finale_diminué_de_aide_finale_formule_initiale |  |
| cat:apl_locatif#traitement_aide_finale_minoration_forfaitaire_de_aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_traitement_aide_finale_minoration_forfaitaire_de_aide_finale_formule_initiale |  |
| cat:apl_locatif#traitement_aide_finale_montée_en_charge_saint_pierre_miquelon_de_aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_traitement_aide_finale_montée_en_charge_saint_pierre_miquelon_de_aide_finale_formule_initiale |  |
| cat:apl_locatif#traitement_aide_finale_réduction_loyer_solidarité_de_aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_traitement_aide_finale_réduction_loyer_solidarité_de_aide_finale_formule_initiale |  |
| cat:apl_locatif#type_aide | input | encoded | input -> a fact the scenario states | rs_type_aide |  |
| cat:apl_locatif#zone | input | encoded | input -> a fact the scenario states | rs_zone |  |
| cat:apl_locatif#âgées_ou_handicap_adultes_hébergées_onéreux_particuliers | input | encoded | input -> a fact the scenario states | rs_âgées_ou_handicap_adultes_hébergées_onéreux_particuliers |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Exemple1 | q_montant_forfaitaire_charges_d823_16 | pass |  |
| Exemple1 | q_participation_minimale | pass |  |
| Exemple1 | q_participation_personnelle | pass |  |
| Exemple1 | q_plafond_loyer_d823_16_2 | pass |  |
| Exemple1 | q_taux_composition_familiale | pass |  |
| Exemple1 | q_traitement_aide_finale_de_aide_finale_formule_initiale | pass |  |
| Exemple2 | q_montant_forfaitaire_charges_d823_16 | pass |  |
| Exemple2 | q_participation_minimale | pass |  |
| Exemple2 | q_participation_personnelle | pass |  |
| Exemple2 | q_plafond_loyer_d823_16_2 | pass |  |
| Exemple2 | q_taux_composition_familiale | pass |  |
| Exemple2 | q_traitement_aide_finale_de_aide_finale_formule_initiale | pass |  |
| Exemple3 | q_montant_forfaitaire_charges_d823_16 | pass |  |
| Exemple3 | q_participation_minimale | pass |  |
| Exemple3 | q_participation_personnelle | pass |  |
| Exemple3 | q_plafond_loyer_d823_16_2 | pass |  |
| Exemple3 | q_taux_composition_familiale | pass |  |
| Exemple3 | q_traitement_aide_finale_de_aide_finale_formule_initiale | pass |  |
| Exemple4 | q_montant_forfaitaire_charges_d823_16 | pass |  |
| Exemple4 | q_participation_minimale | pass |  |
| Exemple4 | q_participation_personnelle | pass |  |
| Exemple4 | q_plafond_loyer_d823_16_2 | pass |  |
| Exemple4 | q_taux_composition_familiale | pass |  |
| Exemple4 | q_traitement_aide_finale_de_aide_finale_formule_initiale | pass |  |
| Exemple5 | q_montant_forfaitaire_charges_d823_16 | pass |  |
| Exemple5 | q_participation_minimale | pass |  |
| Exemple5 | q_participation_personnelle | pass |  |
| Exemple5 | q_plafond_loyer_d823_16_2 | pass |  |
| Exemple5 | q_taux_composition_familiale | pass |  |
| Exemple5 | q_traitement_aide_finale_de_aide_finale_formule_initiale | pass |  |
| Exemple6 | q_montant_forfaitaire_charges_d823_16 | pass |  |
| Exemple6 | q_participation_minimale | pass |  |
| Exemple6 | q_participation_personnelle | pass |  |
| Exemple6 | q_plafond_loyer_d823_16_2 | pass |  |
| Exemple6 | q_taux_composition_familiale | pass |  |
| Exemple6 | q_traitement_aide_finale_de_aide_finale_formule_initiale | pass |  |
| Exemple7 | q_montant_forfaitaire_charges_d823_16 | pass |  |
| Exemple7 | q_participation_minimale | pass |  |
| Exemple7 | q_participation_personnelle | pass |  |
| Exemple7 | q_plafond_loyer_d823_16_2 | pass |  |
| Exemple7 | q_taux_composition_familiale | pass |  |
| Exemple7 | q_traitement_aide_finale_de_aide_finale_formule_initiale | pass |  |
| Exemple8 | q_montant_forfaitaire_charges_d823_16 | pass |  |
| Exemple8 | q_participation_minimale | pass |  |
| Exemple8 | q_participation_personnelle | pass |  |
| Exemple8 | q_plafond_loyer_d823_16_2 | pass |  |
| Exemple8 | q_taux_composition_familiale | pass |  |
| Exemple8 | q_traitement_aide_finale_de_aide_finale_formule_initiale | pass |  |
| Exemple9 | q_traitement_aide_finale_de_aide_finale_formule_initiale | pass |  |

