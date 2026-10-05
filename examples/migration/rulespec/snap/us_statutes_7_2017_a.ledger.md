# Migration ledger: us_statutes_7_2017_a

Source: Axiom RuleSpec — sources/us/statutes/7/2014/e/2/B.yaml, sources/us/statutes/7/2014/e/2.yaml, sources/us/statutes/7/2014/e/6/A.yaml, sources/us/policies/usda/snap/fy-2026-cola/maximum-allotments.yaml, sources/us/statutes/7/2017/a.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-05
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 68 |
| approximated | 0 |
| residue | 0 |
| **total** | 68 |

Fidelity: **17 of 17** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2014/e/2/B#snap_earned_income_deduction_rate | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_earned_income_deduction_rate |  |
| us:statutes/7/2014/e/2/B#snap_earned_income_deduction_rate | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_earned_income_deduction_rate |  |
| us:statutes/7/2014/e/2#snap_earned_income_subject_to_deduction | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_earned_income_subject_to_deduction |  |
| us:statutes/7/2014/e/2#snap_earned_income_subject_to_deduction | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_earned_income_subject_to_deduction |  |
| us:statutes/7/2014/e/2#snap_earned_income_deduction | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_earned_income_deduction |  |
| us:statutes/7/2014/e/2#snap_earned_income_deduction | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_earned_income_deduction |  |
| us:statutes/7/2014/e/6/A#snap_net_income_pre_shelter | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_net_income_pre_shelter |  |
| us:statutes/7/2014/e/6/A#snap_net_income_pre_shelter | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_net_income_pre_shelter |  |
| us:statutes/7/2014/e/6/A#snap_net_income | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_net_income |  |
| us:statutes/7/2014/e/6/A#snap_net_income | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_net_income |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_table | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_additional_member | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_one_person_thrifty_food_plan_cost | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_one_person_thrifty_food_plan_cost |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_one_person_thrifty_food_plan_cost | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_one_person_thrifty_food_plan_cost |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_urban_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_urban_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_urban_table | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_urban_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_urban_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_urban_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_urban_additional_member | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_urban_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_rural_1_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_rural_1_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_rural_1_table | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_rural_1_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_rural_1_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_rural_1_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_rural_1_additional_member | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_rural_1_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_rural_2_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_rural_2_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_rural_2_table | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_rural_2_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_rural_2_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_rural_2_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_alaska_rural_2_additional_member | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_alaska_rural_2_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_guam_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_guam_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_guam_table | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_guam_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_guam_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_guam_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_guam_additional_member | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_guam_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_hawaii_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_hawaii_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_hawaii_table | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_hawaii_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_hawaii_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_hawaii_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_hawaii_additional_member | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_hawaii_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_virgin_islands_table | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_virgin_islands_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_virgin_islands_table | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_virgin_islands_table |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_virgin_islands_additional_member | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_virgin_islands_additional_member |  |
| us:policies/usda/snap/fy-2026-cola/maximum-allotments#snap_maximum_allotment_virgin_islands_additional_member | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_maximum_allotment_virgin_islands_additional_member |  |
| us:statutes/7/2017/a#snap_household_food_contribution_rate | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_household_food_contribution_rate |  |
| us:statutes/7/2017/a#snap_household_food_contribution_rate | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_household_food_contribution_rate |  |
| us:statutes/7/2017/a#snap_minimum_allotment_rate | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_minimum_allotment_rate |  |
| us:statutes/7/2017/a#snap_minimum_allotment_rate | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_minimum_allotment_rate |  |
| us:statutes/7/2017/a#snap_minimum_allotment_household_size_limit | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_minimum_allotment_household_size_limit |  |
| us:statutes/7/2017/a#snap_minimum_allotment_household_size_limit | parameter | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_minimum_allotment_household_size_limit |  |
| us:statutes/7/2017/a#snap_net_income_for_allotment | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_net_income_for_allotment |  |
| us:statutes/7/2017/a#snap_net_income_for_allotment | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_net_income_for_allotment |  |
| us:statutes/7/2017/a#snap_household_food_contribution | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_household_food_contribution |  |
| us:statutes/7/2017/a#snap_household_food_contribution | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_household_food_contribution |  |
| us:statutes/7/2017/a#snap_allotment_before_minimum | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_allotment_before_minimum |  |
| us:statutes/7/2017/a#snap_allotment_before_minimum | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_allotment_before_minimum |  |
| us:statutes/7/2017/a#snap_minimum_monthly_allotment | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_minimum_monthly_allotment |  |
| us:statutes/7/2017/a#snap_minimum_monthly_allotment | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_minimum_monthly_allotment |  |
| us:statutes/7/2017/a#snap_regular_month_allotment | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_regular_month_allotment |  |
| us:statutes/7/2017/a#snap_regular_month_allotment | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_snap_regular_month_allotment |  |
| input snap_countable_earned_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_countable_earned_income |  |
| input work_supplementation_earned_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_work_supplementation_earned_income |  |
| input snap_monthly_household_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_monthly_household_income |  |
| input snap_standard_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_standard_deduction |  |
| input dependent_care_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_dependent_care_deduction |  |
| input child_support_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_child_support_deduction |  |
| input medical_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_medical_deduction |  |
| input snap_excess_shelter_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_excess_shelter_deduction |  |
| input household_size | input | encoded | a name no rule defines -> a fact the scenario states | rs_household_size |  |
| input snap_eligible | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_eligible |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| one_person_eligible_household_receives_thrifty_food_plan_less_thirty_percent_income | q_snap_allotment_before_minimum | pass |  |
| one_person_eligible_household_receives_thrifty_food_plan_less_thirty_percent_income | q_snap_household_food_contribution | pass |  |
| one_person_eligible_household_receives_thrifty_food_plan_less_thirty_percent_income | q_snap_household_food_contribution_rate | pass |  |
| one_person_eligible_household_receives_thrifty_food_plan_less_thirty_percent_income | q_snap_minimum_allotment_household_size_limit | pass |  |
| one_person_eligible_household_receives_thrifty_food_plan_less_thirty_percent_income | q_snap_minimum_allotment_rate | pass |  |
| one_person_eligible_household_receives_thrifty_food_plan_less_thirty_percent_income | q_snap_minimum_monthly_allotment | pass |  |
| one_person_eligible_household_receives_thrifty_food_plan_less_thirty_percent_income | q_snap_net_income_for_allotment | pass |  |
| one_person_eligible_household_receives_thrifty_food_plan_less_thirty_percent_income | q_snap_regular_month_allotment | pass |  |
| two_person_eligible_household_receives_minimum_allotment_when_income_reduction_exceeds_plan_cost | q_snap_allotment_before_minimum | pass |  |
| two_person_eligible_household_receives_minimum_allotment_when_income_reduction_exceeds_plan_cost | q_snap_household_food_contribution | pass |  |
| two_person_eligible_household_receives_minimum_allotment_when_income_reduction_exceeds_plan_cost | q_snap_minimum_monthly_allotment | pass |  |
| two_person_eligible_household_receives_minimum_allotment_when_income_reduction_exceeds_plan_cost | q_snap_net_income_for_allotment | pass |  |
| two_person_eligible_household_receives_minimum_allotment_when_income_reduction_exceeds_plan_cost | q_snap_regular_month_allotment | pass |  |
| three_person_household_has_no_minimum_allotment_under_proviso | q_snap_allotment_before_minimum | pass |  |
| three_person_household_has_no_minimum_allotment_under_proviso | q_snap_minimum_monthly_allotment | pass |  |
| three_person_household_has_no_minimum_allotment_under_proviso | q_snap_regular_month_allotment | pass |  |
| household_not_certified_eligible_receives_no_regular_month_allotment | q_snap_regular_month_allotment | pass |  |

