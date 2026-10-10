# Migration ledger: cat_al_locatif

Source: Catala (catala-examples) — sources/cat/al_locatif.yaml
Translator: lpsPlus migration/catala
Date: 2026-10-10
Source licence: Apache-2.0 (catala-examples, Inria and contributors)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 59 |
| approximated | 13 |
| residue | 0 |
| **total** | 72 |

Fidelity: **5 of 5** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| cat:al_locatif#aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_aide_finale_formule_initiale |  |
| cat:al_locatif#bénéficiaire_aide_adulte_ou_enfant_handicapés | input | encoded | input -> a fact the scenario states | rs_bénéficiaire_aide_adulte_ou_enfant_handicapés |  |
| cat:al_locatif#calcul_apl_locatif_abattement_forfaitaire_d823_17 | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_abattement_forfaitaire_d823_17 | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:al_locatif#calcul_apl_locatif_aide_finale_après_traitement | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_aide_finale_après_traitement |  |
| cat:al_locatif#calcul_apl_locatif_aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_aide_finale_formule_initiale |  |
| cat:al_locatif#calcul_apl_locatif_bénéficiaire_aide_adulte_ou_enfant_handicapés | derived | encoded | derived judgment -> a rule concluding a sentence | rs_calcul_apl_locatif_bénéficiaire_aide_adulte_ou_enfant_handicapés |  |
| cat:al_locatif#calcul_apl_locatif_colocation | derived | encoded | derived judgment -> a rule concluding a sentence | rs_calcul_apl_locatif_colocation |  |
| cat:al_locatif#calcul_apl_locatif_contributions_sociales_date_courante | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_contributions_sociales_date_courante |  |
| cat:al_locatif#calcul_apl_locatif_contributions_sociales_exonéré_csg | derived | encoded | derived judgment -> a rule concluding a sentence | rs_calcul_apl_locatif_contributions_sociales_exonéré_csg |  |
| cat:al_locatif#calcul_apl_locatif_contributions_sociales_lieu | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_contributions_sociales_lieu |  |
| cat:al_locatif#calcul_apl_locatif_contributions_sociales_montant_de_valeur_4191 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_contributions_sociales_montant_de_valeur_4191 |  |
| cat:al_locatif#calcul_apl_locatif_contributions_sociales_montant_de_valeur_8820 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_contributions_sociales_montant_de_valeur_8820 |  |
| cat:al_locatif#calcul_apl_locatif_contributions_sociales_taux_crds | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_contributions_sociales_taux_crds |  |
| cat:al_locatif#calcul_apl_locatif_date_courante | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_date_courante |  |
| cat:al_locatif#calcul_apl_locatif_fraction_l832_3 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_fraction_l832_3 |  |
| cat:al_locatif#calcul_apl_locatif_logement_est_chambre | derived | encoded | derived judgment -> a rule concluding a sentence | rs_calcul_apl_locatif_logement_est_chambre |  |
| cat:al_locatif#calcul_apl_locatif_logement_meublé_d842_2 | derived | encoded | derived judgment -> a rule concluding a sentence | rs_calcul_apl_locatif_logement_meublé_d842_2 |  |
| cat:al_locatif#calcul_apl_locatif_loyer_principal | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_loyer_principal |  |
| cat:al_locatif#calcul_apl_locatif_loyer_référence | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_loyer_référence | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:al_locatif#calcul_apl_locatif_loyer_éligible | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_loyer_éligible |  |
| cat:al_locatif#calcul_apl_locatif_montant_forfaitaire_charges_d823_16 | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_montant_forfaitaire_charges_d823_16 | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:al_locatif#calcul_apl_locatif_montant_forfaitaire_d823_16 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_montant_forfaitaire_d823_16 |  |
| cat:al_locatif#calcul_apl_locatif_montant_minimal_aide_d823_16 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_montant_minimal_aide_d823_16 |  |
| cat:al_locatif#calcul_apl_locatif_multiplicateur_majoration_charges_d823_16 | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_multiplicateur_majoration_charges_d823_16 | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:al_locatif#calcul_apl_locatif_multiplicateur_majoration_loyer_référence | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_multiplicateur_majoration_loyer_référence | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:al_locatif#calcul_apl_locatif_multiplicateur_majoration_plafond_loyer_d823_16_2 | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_multiplicateur_majoration_plafond_loyer_d823_16_2 | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:al_locatif#calcul_apl_locatif_multiplicateur_majoration_r0 | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_multiplicateur_majoration_r0 | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:al_locatif#calcul_apl_locatif_nombre_personnes_à_charge | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_nombre_personnes_à_charge |  |
| cat:al_locatif#calcul_apl_locatif_participation_minimale | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_participation_minimale | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:al_locatif#calcul_apl_locatif_participation_personnelle | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_participation_personnelle |  |
| cat:al_locatif#calcul_apl_locatif_plafond_dégressivité_d823_16 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_plafond_dégressivité_d823_16 |  |
| cat:al_locatif#calcul_apl_locatif_plafond_loyer_d823_16_2 | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_plafond_loyer_d823_16_2 | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:al_locatif#calcul_apl_locatif_plafond_suppression_d823_16 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_plafond_suppression_d823_16 |  |
| cat:al_locatif#calcul_apl_locatif_rapport_loyers | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_rapport_loyers | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:al_locatif#calcul_apl_locatif_ressources_ménage_arrondies | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_ressources_ménage_arrondies |  |
| cat:al_locatif#calcul_apl_locatif_réduction_loyer_solidarité | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_réduction_loyer_solidarité |  |
| cat:al_locatif#calcul_apl_locatif_résidence | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_résidence |  |
| cat:al_locatif#calcul_apl_locatif_situation_familiale_calcul_apl | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_situation_familiale_calcul_apl |  |
| cat:al_locatif#calcul_apl_locatif_taux_composition_familiale | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_taux_composition_familiale | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:al_locatif#calcul_apl_locatif_taux_loyer_éligible | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_taux_loyer_éligible | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:al_locatif#calcul_apl_locatif_taux_loyer_éligible_formule | derived | approximated | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_taux_loyer_éligible_formule | where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first |
| cat:al_locatif#calcul_apl_locatif_taux_prise_compte_ressources | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_taux_prise_compte_ressources |  |
| cat:al_locatif#calcul_apl_locatif_traitement_aide_finale_contributions_sociales_arrondi_de_aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_traitement_aide_finale_contributions_sociales_arrondi_de_aide_finale_formule_initiale |  |
| cat:al_locatif#calcul_apl_locatif_traitement_aide_finale_de_aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_traitement_aide_finale_de_aide_finale_formule_initiale |  |
| cat:al_locatif#calcul_apl_locatif_traitement_aide_finale_diminué_de_aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_traitement_aide_finale_diminué_de_aide_finale_formule_initiale |  |
| cat:al_locatif#calcul_apl_locatif_traitement_aide_finale_minoration_forfaitaire_de_aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_traitement_aide_finale_minoration_forfaitaire_de_aide_finale_formule_initiale |  |
| cat:al_locatif#calcul_apl_locatif_traitement_aide_finale_montée_en_charge_saint_pierre_miquelon_de_aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_traitement_aide_finale_montée_en_charge_saint_pierre_miquelon_de_aide_finale_formule_initiale |  |
| cat:al_locatif#calcul_apl_locatif_traitement_aide_finale_réduction_loyer_solidarité_de_aide_finale_formule_initiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_traitement_aide_finale_réduction_loyer_solidarité_de_aide_finale_formule_initiale |  |
| cat:al_locatif#calcul_apl_locatif_type_aide | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_type_aide |  |
| cat:al_locatif#calcul_apl_locatif_zone | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_calcul_apl_locatif_zone |  |
| cat:al_locatif#calcul_apl_locatif_âgées_ou_handicap_adultes_hébergées_onéreux_particuliers | derived | encoded | derived judgment -> a rule concluding a sentence | rs_calcul_apl_locatif_âgées_ou_handicap_adultes_hébergées_onéreux_particuliers |  |
| cat:al_locatif#changement_logement_d842_4 | input | encoded | input -> a fact the scenario states | rs_changement_logement_d842_4 |  |
| cat:al_locatif#changement_logement_d842_4_Changement_ancien_loyer_principal | input | encoded | input -> a fact the scenario states | rs_changement_logement_d842_4_Changement_ancien_loyer_principal |  |
| cat:al_locatif#changement_logement_d842_4_Changement_ancienne_allocation_logement | input | encoded | input -> a fact the scenario states | rs_changement_logement_d842_4_Changement_ancienne_allocation_logement |  |
| cat:al_locatif#colocation | input | encoded | input -> a fact the scenario states | rs_colocation |  |
| cat:al_locatif#date_courante | input | encoded | input -> a fact the scenario states | rs_date_courante |  |
| cat:al_locatif#logement_est_chambre | input | encoded | input -> a fact the scenario states | rs_logement_est_chambre |  |
| cat:al_locatif#logement_meublé_d842_2 | input | encoded | input -> a fact the scenario states | rs_logement_meublé_d842_2 |  |
| cat:al_locatif#loyer_principal | input | encoded | input -> a fact the scenario states | rs_loyer_principal |  |
| cat:al_locatif#montant_forfaitaire_charges_d823_16 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_montant_forfaitaire_charges_d823_16 |  |
| cat:al_locatif#nombre_personnes_à_charge | input | encoded | input -> a fact the scenario states | rs_nombre_personnes_à_charge |  |
| cat:al_locatif#participation_minimale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_participation_minimale |  |
| cat:al_locatif#participation_personnelle | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_participation_personnelle |  |
| cat:al_locatif#plafond_loyer_d823_16_2 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_plafond_loyer_d823_16_2 |  |
| cat:al_locatif#ressources_ménage_arrondies | input | encoded | input -> a fact the scenario states | rs_ressources_ménage_arrondies |  |
| cat:al_locatif#réduction_loyer_solidarité | input | encoded | input -> a fact the scenario states | rs_réduction_loyer_solidarité |  |
| cat:al_locatif#résidence | input | encoded | input -> a fact the scenario states | rs_résidence |  |
| cat:al_locatif#situation_familiale_calcul_apl | input | encoded | input -> a fact the scenario states | rs_situation_familiale_calcul_apl |  |
| cat:al_locatif#taux_composition_familiale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_taux_composition_familiale |  |
| cat:al_locatif#type_aide | input | encoded | input -> a fact the scenario states | rs_type_aide |  |
| cat:al_locatif#zone | input | encoded | input -> a fact the scenario states | rs_zone |  |
| cat:al_locatif#âgées_ou_handicap_adultes_hébergées_onéreux_particuliers | input | encoded | input -> a fact the scenario states | rs_âgées_ou_handicap_adultes_hébergées_onéreux_particuliers |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Exemple4 | q_montant_forfaitaire_charges_d823_16 | pass |  |
| Exemple4 | q_participation_minimale | pass |  |
| Exemple4 | q_participation_personnelle | pass |  |
| Exemple4 | q_plafond_loyer_d823_16_2 | pass |  |
| Exemple4 | q_taux_composition_familiale | pass |  |

