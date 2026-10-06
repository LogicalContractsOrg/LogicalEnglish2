# Migration ledger: us_policies_usda_snap_fy_2026_cola_deductions

Source: Axiom RuleSpec — sources/us/statutes/7/2012/j.yaml, sources/us/policies/usda/snap/fy-2026-cola/deductions.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-06
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 20 |
| approximated | 0 |
| residue | 0 |
| **total** | 20 |

Fidelity: **18 of 18** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2012/j#member_of_household | data_relation | encoded | data relation -> a two-place sentence the scenario states | rs_member_of_household |  |
| us:statutes/7/2012/j#snap_household_has_elderly_or_disabled_member | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_snap_household_has_elderly_or_disabled_member |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_standard_deduction_48_states_dc_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_standard_deduction_48_states_dc_table |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_standard_deduction_48_states_dc | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_standard_deduction_48_states_dc |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_standard_deduction | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_standard_deduction |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_maximum_excess_shelter_deduction_48_states_dc | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_excess_shelter_deduction_48_states_dc |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_standard_deduction_alaska_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_standard_deduction_alaska_table |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_standard_deduction_guam_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_standard_deduction_guam_table |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_standard_deduction_hawaii_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_standard_deduction_hawaii_table |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_standard_deduction_virgin_islands_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_standard_deduction_virgin_islands_table |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_maximum_excess_shelter_deduction_alaska | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_excess_shelter_deduction_alaska |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_maximum_excess_shelter_deduction_guam | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_excess_shelter_deduction_guam |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_maximum_excess_shelter_deduction_hawaii | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_excess_shelter_deduction_hawaii |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_maximum_excess_shelter_deduction_virgin_islands | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_excess_shelter_deduction_virgin_islands |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_homeless_shelter_deduction | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_homeless_shelter_deduction |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_asset_limit_elderly_or_disabled_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_asset_limit_elderly_or_disabled_member |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_asset_limit_other_households | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_asset_limit_other_households |  |
| us:policies/usda/snap/fy-2026-cola/deductions#snap_asset_limit | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_asset_limit |  |
| input snap_member_is_elderly_or_disabled | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_member_is_elderly_or_disabled |  |
| input household_size | input | encoded | a name no rule defines -> a fact the scenario states | rs_household_size |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| standard_deduction_for_one_person_household | q_snap_standard_deduction | pass |  |
| standard_deduction_for_one_person_household | q_snap_standard_deduction_48_states_dc | pass |  |
| standard_deduction_for_five_person_household | q_snap_standard_deduction | pass |  |
| standard_deduction_for_five_person_household | q_snap_standard_deduction_48_states_dc | pass |  |
| regional_deduction_parameters_for_six_person_household | q_snap_homeless_shelter_deduction | pass |  |
| regional_deduction_parameters_for_six_person_household | q_snap_maximum_excess_shelter_deduction_48_states_dc | pass |  |
| regional_deduction_parameters_for_six_person_household | q_snap_maximum_excess_shelter_deduction_alaska | pass |  |
| regional_deduction_parameters_for_six_person_household | q_snap_maximum_excess_shelter_deduction_guam | pass |  |
| regional_deduction_parameters_for_six_person_household | q_snap_maximum_excess_shelter_deduction_hawaii | pass |  |
| regional_deduction_parameters_for_six_person_household | q_snap_maximum_excess_shelter_deduction_virgin_islands | pass |  |
| standard_deduction_for_six_or_more_person_household | q_snap_standard_deduction | pass |  |
| standard_deduction_for_six_or_more_person_household | q_snap_standard_deduction_48_states_dc | pass |  |
| asset_limit_for_household_with_elderly_or_disabled_member | q_snap_asset_limit | pass |  |
| asset_limit_for_household_with_elderly_or_disabled_member | q_snap_asset_limit_elderly_or_disabled_member | pass |  |
| asset_limit_for_household_with_elderly_or_disabled_member | q_snap_household_has_elderly_or_disabled_member | pass |  |
| asset_limit_for_other_households | q_snap_asset_limit | pass |  |
| asset_limit_for_other_households | q_snap_asset_limit_other_households | pass |  |
| asset_limit_for_other_households | q_snap_household_has_elderly_or_disabled_member | pass |  |

