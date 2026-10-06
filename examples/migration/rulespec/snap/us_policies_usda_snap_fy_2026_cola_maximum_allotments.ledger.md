# Migration ledger: us_policies_usda_snap_fy_2026_cola_maximum_allotments

Source: Axiom RuleSpec — sources/us/policies/usda/snap/fy-2026-cola/maximum-allotments.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-06
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 17 |
| approximated | 0 |
| residue | 0 |
| **total** | 17 |

Fidelity: **11 of 11** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_one_person_thrifty_food_plan_cost | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_one_person_thrifty_food_plan_cost |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_urban_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_urban_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_urban_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_urban_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_rural_1_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_rural_1_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_rural_1_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_rural_1_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_rural_2_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_rural_2_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_rural_2_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_rural_2_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_guam_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_guam_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_guam_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_guam_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_hawaii_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_hawaii_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_hawaii_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_hawaii_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_virgin_islands_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_virgin_islands_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_virgin_islands_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_virgin_islands_additional_member |  |
| input household_size | input | encoded | a name no rule defines -> a fact the scenario states | rs_household_size |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| snap_maximum_allotment_for_one_person_household | q_snap_maximum_allotment | pass |  |
| snap_maximum_allotment_for_one_person_household | q_snap_one_person_thrifty_food_plan_cost | pass |  |
| snap_maximum_allotment_for_eight_person_household | q_snap_maximum_allotment | pass |  |
| snap_maximum_allotment_adds_each_additional_person | q_snap_maximum_allotment | pass |  |
| snap_maximum_allotment_adds_each_additional_person | q_snap_maximum_allotment_additional_member | pass |  |
| snap_maximum_allotment_adds_each_additional_person | q_snap_maximum_allotment_alaska_rural_1_additional_member | pass |  |
| snap_maximum_allotment_adds_each_additional_person | q_snap_maximum_allotment_alaska_rural_2_additional_member | pass |  |
| snap_maximum_allotment_adds_each_additional_person | q_snap_maximum_allotment_alaska_urban_additional_member | pass |  |
| snap_maximum_allotment_adds_each_additional_person | q_snap_maximum_allotment_guam_additional_member | pass |  |
| snap_maximum_allotment_adds_each_additional_person | q_snap_maximum_allotment_hawaii_additional_member | pass |  |
| snap_maximum_allotment_adds_each_additional_person | q_snap_maximum_allotment_virgin_islands_additional_member | pass |  |

