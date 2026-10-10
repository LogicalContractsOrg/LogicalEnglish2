# Migration ledger: cat_section_121

Source: Catala (catala-examples) — sources/cat/section_121.yaml
Translator: lpsPlus migration/catala
Date: 2026-10-10
Source licence: Apache-2.0 (catala-examples, Inria and contributors)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 85 |
| approximated | 0 |
| residue | 0 |
| **total** | 85 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| cat:section_121#begin | input | encoded | input -> a fact the scenario states | rs_begin |  |
| cat:section_121#end | input | encoded | input -> a fact the scenario states | rs_end |  |
| cat:section_121#is_in_section121_single_person_property_ownage | input | encoded | input -> a fact the scenario states | rs_is_in_section121_single_person_property_ownage |  |
| cat:section_121#is_in_section121_single_person_property_usage_as_principal_residence | input | encoded | input -> a fact the scenario states | rs_is_in_section121_single_person_property_usage_as_principal_residence |  |
| cat:section_121#is_in_section121_two_persons_period_merge_output_periods | derived | encoded | derived judgment -> a rule concluding a sentence | rs_is_in_section121_two_persons_period_merge_output_periods |  |
| cat:section_121#is_in_section121_two_persons_period_merge_periods1 | derived | encoded | derived judgment -> a rule concluding a sentence | rs_is_in_section121_two_persons_period_merge_periods1 |  |
| cat:section_121#is_in_section121_two_persons_period_merge_periods2 | derived | encoded | derived judgment -> a rule concluding a sentence | rs_is_in_section121_two_persons_period_merge_periods2 |  |
| cat:section_121#is_in_section121_two_persons_person1_property_ownage | derived | encoded | derived judgment -> a rule concluding a sentence | rs_is_in_section121_two_persons_person1_property_ownage |  |
| cat:section_121#is_in_section121_two_persons_person1_property_usage_as_principal_residence | derived | encoded | derived judgment -> a rule concluding a sentence | rs_is_in_section121_two_persons_person1_property_usage_as_principal_residence |  |
| cat:section_121#is_in_section121_two_persons_person2_property_ownage | derived | encoded | derived judgment -> a rule concluding a sentence | rs_is_in_section121_two_persons_person2_property_ownage |  |
| cat:section_121#is_in_section121_two_persons_person2_property_usage_as_principal_residence | derived | encoded | derived judgment -> a rule concluding a sentence | rs_is_in_section121_two_persons_person2_property_usage_as_principal_residence |  |
| cat:section_121#is_in_section121_two_persons_return_type_JointReturn_person1_property_ownage | input | encoded | input -> a fact the scenario states | rs_is_in_section121_two_persons_return_type_JointReturn_person1_property_ownage |  |
| cat:section_121#is_in_section121_two_persons_return_type_JointReturn_person1_property_usage_as_principal_residence | input | encoded | input -> a fact the scenario states | rs_is_in_section121_two_persons_return_type_JointReturn_person1_property_usage_as_principal_residence |  |
| cat:section_121#is_in_section121_two_persons_return_type_JointReturn_person2_property_ownage | input | encoded | input -> a fact the scenario states | rs_is_in_section121_two_persons_return_type_JointReturn_person2_property_ownage |  |
| cat:section_121#is_in_section121_two_persons_return_type_JointReturn_person2_property_usage_as_principal_residence | input | encoded | input -> a fact the scenario states | rs_is_in_section121_two_persons_return_type_JointReturn_person2_property_usage_as_principal_residence |  |
| cat:section_121#is_in_section121_two_persons_return_type_SingleReturnSurvivingSpouse_death_spouse_info_at_time_of_death_property_ownage | input | encoded | input -> a fact the scenario states | rs_is_in_section121_two_persons_return_type_SingleReturnSurvivingSpouse_death_spouse_info_at_time_of_death_property_ownage |  |
| cat:section_121#is_in_section121_two_persons_return_type_SingleReturnSurvivingSpouse_death_spouse_info_at_time_of_death_property_usage_as_principal_residence | input | encoded | input -> a fact the scenario states | rs_is_in_section121_two_persons_return_type_SingleReturnSurvivingSpouse_death_spouse_info_at_time_of_death_property_usage_as_principal_residence |  |
| cat:section_121#is_in_section121_two_persons_return_type_SingleReturnSurvivingSpouse_return_property_ownage | input | encoded | input -> a fact the scenario states | rs_is_in_section121_two_persons_return_type_SingleReturnSurvivingSpouse_return_property_ownage |  |
| cat:section_121#is_in_section121_two_persons_return_type_SingleReturnSurvivingSpouse_return_property_usage_as_principal_residence | input | encoded | input -> a fact the scenario states | rs_is_in_section121_two_persons_return_type_SingleReturnSurvivingSpouse_return_property_usage_as_principal_residence |  |
| cat:section_121#is_in_section121_two_persons_return_type_SingleReturn_property_ownage | input | encoded | input -> a fact the scenario states | rs_is_in_section121_two_persons_return_type_SingleReturn_property_ownage |  |
| cat:section_121#is_in_section121_two_persons_return_type_SingleReturn_property_usage_as_principal_residence | input | encoded | input -> a fact the scenario states | rs_is_in_section121_two_persons_return_type_SingleReturn_property_usage_as_principal_residence |  |
| cat:section_121#is_in_section121_two_persons_section121Person1_property_ownage | derived | encoded | derived judgment -> a rule concluding a sentence | rs_is_in_section121_two_persons_section121Person1_property_ownage |  |
| cat:section_121#is_in_section121_two_persons_section121Person1_property_usage_as_principal_residence | derived | encoded | derived judgment -> a rule concluding a sentence | rs_is_in_section121_two_persons_section121Person1_property_usage_as_principal_residence |  |
| cat:section_121#is_in_section121_two_persons_section121Person2_property_ownage | derived | encoded | derived judgment -> a rule concluding a sentence | rs_is_in_section121_two_persons_section121Person2_property_ownage |  |
| cat:section_121#is_in_section121_two_persons_section121Person2_property_usage_as_principal_residence | derived | encoded | derived judgment -> a rule concluding a sentence | rs_is_in_section121_two_persons_section121Person2_property_usage_as_principal_residence |  |
| cat:section_121#section121_single_person_date_of_sale_or_exchange | input | encoded | input -> a fact the scenario states | rs_section121_single_person_date_of_sale_or_exchange |  |
| cat:section_121#section121_single_person_gain_cap | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_single_person_gain_cap |  |
| cat:section_121#section121_single_person_gain_from_sale_or_exchange_of_property | input | encoded | input -> a fact the scenario states | rs_section121_single_person_gain_from_sale_or_exchange_of_property |  |
| cat:section_121#section121_single_person_income_excluded_from_gross_income | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_single_person_income_excluded_from_gross_income |  |
| cat:section_121#section121_single_person_income_excluded_from_gross_income_uncapped | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_single_person_income_excluded_from_gross_income_uncapped |  |
| cat:section_121#section121_single_person_other_section_121a_sale | input | encoded | input -> a fact the scenario states | rs_section121_single_person_other_section_121a_sale |  |
| cat:section_121#section121_single_person_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange | input | encoded | input -> a fact the scenario states | rs_section121_single_person_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange |  |
| cat:section_121#section121_single_person_requirements_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_single_person_requirements_met |  |
| cat:section_121#section121_single_person_requirements_ownership_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_single_person_requirements_ownership_met |  |
| cat:section_121#section121_single_person_requirements_usage_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_single_person_requirements_usage_met |  |
| cat:section_121#section121_single_person_section_121_b_3_applies | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_single_person_section_121_b_3_applies |  |
| cat:section_121#section121_two_persons_date_of_sale_or_exchange | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_gain_cap | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_gain_cap |  |
| cat:section_121#section121_two_persons_gain_cap_person_1 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_gain_cap_person_1 |  |
| cat:section_121#section121_two_persons_gain_cap_person_2 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_gain_cap_person_2 |  |
| cat:section_121#section121_two_persons_gain_from_sale_or_exchange_of_property | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_gain_from_sale_or_exchange_of_property |  |
| cat:section_121#section121_two_persons_income_excluded_from_gross_income | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_income_excluded_from_gross_income |  |
| cat:section_121#section121_two_persons_income_excluded_from_gross_income_uncapped | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_income_excluded_from_gross_income_uncapped |  |
| cat:section_121#section121_two_persons_person1_other_section_121a_sale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_person1_other_section_121a_sale |  |
| cat:section_121#section121_two_persons_person1_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_person1_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_person2_other_section_121a_sale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_person2_other_section_121a_sale |  |
| cat:section_121#section121_two_persons_person2_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_person2_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_return_date | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_date |  |
| cat:section_121#section121_two_persons_return_type | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_type |  |
| cat:section_121#section121_two_persons_return_type_JointReturn_person1_other_section_121a_sale | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_type_JointReturn_person1_other_section_121a_sale |  |
| cat:section_121#section121_two_persons_return_type_JointReturn_person1_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_type_JointReturn_person1_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_return_type_JointReturn_person2_other_section_121a_sale | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_type_JointReturn_person2_other_section_121a_sale |  |
| cat:section_121#section121_two_persons_return_type_JointReturn_person2_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_type_JointReturn_person2_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_return_type_SingleReturnSurvivingSpouse_date_of_spouse_death | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_type_SingleReturnSurvivingSpouse_date_of_spouse_death |  |
| cat:section_121#section121_two_persons_return_type_SingleReturnSurvivingSpouse_death_spouse_info_at_time_of_death_other_section_121a_sale | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_type_SingleReturnSurvivingSpouse_death_spouse_info_at_time_of_death_other_section_121a_sale |  |
| cat:section_121#section121_two_persons_return_type_SingleReturnSurvivingSpouse_death_spouse_info_at_time_of_death_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_type_SingleReturnSurvivingSpouse_death_spouse_info_at_time_of_death_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_return_type_SingleReturnSurvivingSpouse_return_other_section_121a_sale | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_type_SingleReturnSurvivingSpouse_return_other_section_121a_sale |  |
| cat:section_121#section121_two_persons_return_type_SingleReturnSurvivingSpouse_return_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_type_SingleReturnSurvivingSpouse_return_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_return_type_SingleReturn_other_section_121a_sale | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_type_SingleReturn_other_section_121a_sale |  |
| cat:section_121#section121_two_persons_return_type_SingleReturn_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_type_SingleReturn_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_section121Person1_date_of_sale_or_exchange | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person1_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_section121Person1_gain_cap | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person1_gain_cap |  |
| cat:section_121#section121_two_persons_section121Person1_gain_from_sale_or_exchange_of_property | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person1_gain_from_sale_or_exchange_of_property |  |
| cat:section_121#section121_two_persons_section121Person1_income_excluded_from_gross_income | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person1_income_excluded_from_gross_income |  |
| cat:section_121#section121_two_persons_section121Person1_income_excluded_from_gross_income_uncapped | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person1_income_excluded_from_gross_income_uncapped |  |
| cat:section_121#section121_two_persons_section121Person1_other_section_121a_sale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person1_other_section_121a_sale |  |
| cat:section_121#section121_two_persons_section121Person1_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person1_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_section121Person1_requirements_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121Person1_requirements_met |  |
| cat:section_121#section121_two_persons_section121Person1_requirements_ownership_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121Person1_requirements_ownership_met |  |
| cat:section_121#section121_two_persons_section121Person1_requirements_usage_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121Person1_requirements_usage_met |  |
| cat:section_121#section121_two_persons_section121Person1_section_121_b_3_applies | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121Person1_section_121_b_3_applies |  |
| cat:section_121#section121_two_persons_section121Person2_date_of_sale_or_exchange | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person2_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_section121Person2_gain_cap | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person2_gain_cap |  |
| cat:section_121#section121_two_persons_section121Person2_gain_from_sale_or_exchange_of_property | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person2_gain_from_sale_or_exchange_of_property |  |
| cat:section_121#section121_two_persons_section121Person2_income_excluded_from_gross_income | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person2_income_excluded_from_gross_income |  |
| cat:section_121#section121_two_persons_section121Person2_income_excluded_from_gross_income_uncapped | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person2_income_excluded_from_gross_income_uncapped |  |
| cat:section_121#section121_two_persons_section121Person2_other_section_121a_sale | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person2_other_section_121a_sale |  |
| cat:section_121#section121_two_persons_section121Person2_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person2_other_section_121a_sale_MostRecentSaleWhereSection121aApplied_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_section121Person2_requirements_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121Person2_requirements_met |  |
| cat:section_121#section121_two_persons_section121Person2_requirements_ownership_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121Person2_requirements_ownership_met |  |
| cat:section_121#section121_two_persons_section121Person2_requirements_usage_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121Person2_requirements_usage_met |  |
| cat:section_121#section121_two_persons_section121Person2_section_121_b_3_applies | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121Person2_section_121_b_3_applies |  |
| cat:section_121#section121_two_persons_section121a_requirements_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121a_requirements_met |  |
| cat:section_121#section121_two_persons_section_121_b_2_A_condition | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section_121_b_2_A_condition |  |
| input Period | input | encoded | a name no rule defines -> a fact the scenario states | rs_Period |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Test1 | q_section121_single_person_requirements_met | pass |  |
| Test2 | q_section121_single_person_requirements_met | pass |  |
| Test3 | q_section121_single_person_requirements_met | pass |  |
| Test4 | q_section121_single_person_requirements_met | pass |  |
| Test5 | q_section121_two_persons_income_excluded_from_gross_income | pass |  |
| Test6 | q_section121_two_persons_income_excluded_from_gross_income | pass |  |

