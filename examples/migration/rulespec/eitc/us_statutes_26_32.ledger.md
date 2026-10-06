# Migration ledger: us_statutes_26_32

Source: Axiom RuleSpec — sources/us/statutes/26/112.yaml, sources/us/statutes/26/32/c/2.yaml, sources/us/statutes/26/152/c.yaml, sources/us/statutes/26/911/a.yaml, sources/us/statutes/26/931.yaml, sources/us/statutes/26/933.yaml, sources/us/statutes/26/151.yaml, sources/us/statutes/26/7703.yaml, sources/us/policies/irs/rev-proc-2025-32/earned-income-credit.yaml, sources/us/statutes/26/32.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-06
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 202 |
| approximated | 2 |
| residue | 0 |
| **total** | 204 |

Fidelity: **28 of 28** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/26/112#hospitalization_after_combat_zone_termination_limit_years | parameter | encoded | parameter -> a fact, cited | rs_hospitalization_after_combat_zone_termination_limit_years |  |
| us:statutes/26/112#amount_excluded_from_gross_income_by_reason_of_section_112 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_amount_excluded_from_gross_income_by_reason_of_section_112 |  |
| us:statutes/26/32/c/2#earned_income_before_section_112_election | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_earned_income_before_section_112_election |  |
| us:statutes/26/32/c/2#earned_income | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_earned_income |  |
| us:statutes/26/152/c#abode_fraction_threshold | parameter | encoded | parameter -> a fact, cited | rs_abode_fraction_threshold |  |
| us:statutes/26/152/c#support_fraction_threshold | parameter | encoded | parameter -> a fact, cited | rs_support_fraction_threshold |  |
| us:statutes/26/152/c#child_age_limit | parameter | encoded | parameter -> a fact, cited | rs_child_age_limit |  |
| us:statutes/26/152/c#student_age_limit | parameter | encoded | parameter -> a fact, cited | rs_student_age_limit |  |
| us:statutes/26/152/c#qualifying_child_relationship | derived | encoded | derived judgment -> a rule concluding a sentence | rs_qualifying_child_relationship |  |
| us:statutes/26/152/c#age_requirements_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_age_requirements_met |  |
| us:statutes/26/152/c#individual_filed_joint_return_with_spouse_other_than_only_for_claim_of_refund | derived | encoded | derived judgment -> a rule concluding a sentence | rs_individual_filed_joint_return_with_spouse_other_than_only_for_claim_of_refund |  |
| us:statutes/26/152/c#parents_claiming_child_do_not_file_joint_return_together | derived | encoded | derived judgment -> a rule concluding a sentence | rs_parents_claiming_child_do_not_file_joint_return_together |  |
| us:statutes/26/152/c#qualifying_child_before_tiebreaker | derived | encoded | derived judgment -> a rule concluding a sentence | rs_qualifying_child_before_tiebreaker |  |
| us:statutes/26/152/c#tiebreaker_treats_individual_as_qualifying_child_of_taxpayer | derived | encoded | derived judgment -> a rule concluding a sentence | rs_tiebreaker_treats_individual_as_qualifying_child_of_taxpayer |  |
| us:statutes/26/152/c#qualifying_child | derived | encoded | derived judgment -> a rule concluding a sentence | rs_qualifying_child |  |
| us:statutes/26/911/a#foreign_earned_income_excluded_from_gross_income | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_foreign_earned_income_excluded_from_gross_income |  |
| us:statutes/26/911/a#housing_cost_amount_excluded_from_gross_income | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_housing_cost_amount_excluded_from_gross_income |  |
| us:statutes/26/911/a#section_911_amount_excluded_from_gross_income | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_section_911_amount_excluded_from_gross_income |  |
| us:statutes/26/911/a#section_911_amount_exempt_from_taxation | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_section_911_amount_exempt_from_taxation |  |
| us:statutes/26/931#possession_is_specified_possession | derived | encoded | derived judgment -> a rule concluding a sentence | rs_possession_is_specified_possession |  |
| us:statutes/26/931#amount_excluded_from_gross_income_under_section_931 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_amount_excluded_from_gross_income_under_section_931 |  |
| us:statutes/26/931#section_931_disallowed_deductions_excluding_section_151 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section_931_disallowed_deductions_excluding_section_151 |  |
| us:statutes/26/931#deductions_other_than_section_151_allowed_after_section_931 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_deductions_other_than_section_151_allowed_after_section_931 |  |
| us:statutes/26/931#section_931_disallowed_credits | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section_931_disallowed_credits |  |
| us:statutes/26/931#credits_allowed_after_section_931 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_credits_allowed_after_section_931 |  |
| us:statutes/26/933#puerto_rico_residence_before_change_minimum_years | parameter | encoded | parameter -> a fact, cited | rs_puerto_rico_residence_before_change_minimum_years |  |
| us:statutes/26/933#entire_year_puerto_rico_source_income_excluded | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_entire_year_puerto_rico_source_income_excluded |  |
| us:statutes/26/933#change_year_puerto_rico_source_income_excluded | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_change_year_puerto_rico_source_income_excluded |  |
| us:statutes/26/933#income_excluded_from_gross_income_under_section_933 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_income_excluded_from_gross_income_under_section_933 |  |
| us:statutes/26/933#section_933_disallowed_deductions_other_than_section_151 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section_933_disallowed_deductions_other_than_section_151 |  |
| us:statutes/26/933#section_933_disallowed_credits | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section_933_disallowed_credits |  |
| us:statutes/26/151#exemption_individual_of_tax_unit | data_relation | encoded | data relation -> a two-place sentence the scenario states | rs_exemption_individual_of_tax_unit |  |
| us:statutes/26/151#senior_deduction_individual_of_tax_unit | data_relation | encoded | data relation -> a two-place sentence the scenario states | rs_senior_deduction_individual_of_tax_unit |  |
| us:statutes/26/151#statutory_exemption_amount_base | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_statutory_exemption_amount_base |  |
| us:statutes/26/151#exemption_phaseout_rate_per_increment | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_exemption_phaseout_rate_per_increment |  |
| us:statutes/26/151#exemption_phaseout_increment | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_exemption_phaseout_increment |  |
| us:statutes/26/151#exemption_phaseout_increment_separate | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_exemption_phaseout_increment_separate |  |
| us:statutes/26/151#exemption_phaseout_maximum_percentage | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_exemption_phaseout_maximum_percentage |  |
| us:statutes/26/151#post_2017_exemption_amount | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_post_2017_exemption_amount |  |
| us:statutes/26/151#senior_deduction_base_amount | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_senior_deduction_base_amount |  |
| us:statutes/26/151#senior_deduction_age_threshold | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_senior_deduction_age_threshold |  |
| us:statutes/26/151#senior_deduction_phaseout_rate | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_senior_deduction_phaseout_rate |  |
| us:statutes/26/151#senior_deduction_phaseout_threshold_other | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_senior_deduction_phaseout_threshold_other |  |
| us:statutes/26/151#senior_deduction_phaseout_threshold_joint | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_senior_deduction_phaseout_threshold_joint |  |
| us:statutes/26/151#exemption_amount | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_exemption_amount |  |
| us:statutes/26/151#exemption_individual_eligible | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_exemption_individual_eligible |  |
| us:statutes/26/151#section_151_exemption_deduction | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_section_151_exemption_deduction |  |
| us:statutes/26/151#senior_deduction_qualified_individual | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_senior_deduction_qualified_individual |  |
| us:statutes/26/151#senior_deduction_modified_adjusted_gross_income | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_senior_deduction_modified_adjusted_gross_income |  |
| us:statutes/26/151#senior_deduction_phaseout_threshold | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_senior_deduction_phaseout_threshold |  |
| us:statutes/26/151#senior_deduction_amount_per_qualified_individual | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_senior_deduction_amount_per_qualified_individual |  |
| us:statutes/26/151#senior_deduction_eligible | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_senior_deduction_eligible |  |
| us:statutes/26/151#senior_deduction | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_senior_deduction |  |
| us:statutes/26/7703#living_apart_child_of_tax_unit | data_relation | encoded | data relation -> a two-place sentence the scenario states | rs_living_apart_child_of_tax_unit |  |
| us:statutes/26/7703#child_principal_abode_fraction_threshold | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_child_principal_abode_fraction_threshold |  |
| us:statutes/26/7703#household_cost_fraction_threshold | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_household_cost_fraction_threshold |  |
| us:statutes/26/7703#spouse_absence_period_months | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_spouse_absence_period_months |  |
| us:statutes/26/7703#taxpayer_married_under_general_rule | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_taxpayer_married_under_general_rule |  |
| us:statutes/26/7703#living_apart_child_has_required_abode_and_deduction | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_living_apart_child_has_required_abode_and_deduction |  |
| us:statutes/26/7703#taxpayer_not_considered_married_when_living_apart | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_taxpayer_not_considered_married_when_living_apart |  |
| us:statutes/26/7703#taxpayer_considered_married_after_living_apart_rule | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_taxpayer_considered_married_after_living_apart_rule |  |
| us:policies/irs/rev-proc-2025-32/earned-income-credit#eitc_earned_income_amounts | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_eitc_earned_income_amounts |  |
| us:policies/irs/rev-proc-2025-32/earned-income-credit#eitc_maximum_credit_amounts | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_eitc_maximum_credit_amounts |  |
| us:policies/irs/rev-proc-2025-32/earned-income-credit#eitc_threshold_phaseout_amounts_joint | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_eitc_threshold_phaseout_amounts_joint |  |
| us:policies/irs/rev-proc-2025-32/earned-income-credit#eitc_completed_phaseout_amounts_joint | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_eitc_completed_phaseout_amounts_joint |  |
| us:policies/irs/rev-proc-2025-32/earned-income-credit#eitc_threshold_phaseout_amounts_other | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_eitc_threshold_phaseout_amounts_other |  |
| us:policies/irs/rev-proc-2025-32/earned-income-credit#eitc_completed_phaseout_amounts_other | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_eitc_completed_phaseout_amounts_other |  |
| us:policies/irs/rev-proc-2025-32/earned-income-credit#eitc_maximum_investment_income | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_eitc_maximum_investment_income |  |
| us:statutes/26/32#qualifying_child_of_tax_unit | data_relation | encoded | data relation -> a two-place sentence the scenario states | rs_qualifying_child_of_tax_unit |  |
| us:statutes/26/32#eitc_phase_in_rates | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_eitc_phase_in_rates |  |
| us:statutes/26/32#eitc_phase_out_rates | parameter | encoded | indexed parameter -> one fact per row, 1 version(s) guarded by the calculation date | rs_eitc_phase_out_rates |  |
| us:statutes/26/32#eitc_childless_minimum_age | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_eitc_childless_minimum_age |  |
| us:statutes/26/32#eitc_childless_age_ceiling_exclusive | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_eitc_childless_age_ceiling_exclusive |  |
| us:statutes/26/32#eitc_qualifying_child_base | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_eitc_qualifying_child_base |  |
| us:statutes/26/32#eitc_qualifying_child | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_eitc_qualifying_child |  |
| us:statutes/26/32#eitc_child_count | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_eitc_child_count |  |
| us:statutes/26/32#eitc_capped_child_count | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_eitc_capped_child_count |  |
| us:statutes/26/32#eitc_phase_in_rate | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_eitc_phase_in_rate |  |
| us:statutes/26/32#eitc_phase_out_rate | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_eitc_phase_out_rate |  |
| us:statutes/26/32#eitc_earned_income_amount | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_eitc_earned_income_amount |  |
| us:statutes/26/32#eitc_maximum | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_eitc_maximum |  |
| us:statutes/26/32#eitc_phase_out_start | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_eitc_phase_out_start |  |
| us:statutes/26/32#eitc_phase_out_income | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_eitc_phase_out_income |  |
| us:statutes/26/32#eitc_phased_in | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_eitc_phased_in |  |
| us:statutes/26/32#eitc_reduction | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_eitc_reduction |  |
| us:statutes/26/32#eitc_before_eligibility | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_eitc_before_eligibility |  |
| us:statutes/26/32#eitc_childless_age_eligible | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_eitc_childless_age_eligible |  |
| us:statutes/26/32#eitc_demographic_eligible | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_eitc_demographic_eligible |  |
| us:statutes/26/32#eitc_identification_requirements_satisfied | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_eitc_identification_requirements_satisfied |  |
| us:statutes/26/32#eitc_investment_income_eligible | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_eitc_investment_income_eligible |  |
| us:statutes/26/32#eitc_allowed | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_eitc_allowed |  |
| us:statutes/26/32#eitc | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_eitc |  |
| input member_below_grade_of_commissioned_officer_in_armed_forces | input | encoded | a name no rule defines -> a fact the scenario states | rs_member_below_grade_of_commissioned_officer_in_armed_forces |  |
| input served_in_combat_zone_during_month | input | encoded | a name no rule defines -> a fact the scenario states | rs_served_in_combat_zone_during_month |  |
| input hospitalized_resulting_from_combat_zone_wounds_disease_or_injury | input | encoded | a name no rule defines -> a fact the scenario states | rs_hospitalized_resulting_from_combat_zone_wounds_disease_or_injury |  |
| input months_beginning_after_combatant_activities_termination | input | encoded | a name no rule defines -> a fact the scenario states | rs_months_beginning_after_combatant_activities_termination |  |
| input vietnam_combat_zone_hospitalization_month_after_january_1978 | input | encoded | a name no rule defines -> a fact the scenario states | rs_vietnam_combat_zone_hospitalization_month_after_january_1978 |  |
| input active_service_compensation_as_enlisted_member_excluding_pensions_and_retirement_pay | input | encoded | a name no rule defines -> a fact the scenario states | rs_active_service_compensation_as_enlisted_member_excluding_pensions_and_retirement_pay |  |
| input commissioned_officer_in_armed_forces_excluding_commissioned_warrant_officer | input | encoded | a name no rule defines -> a fact the scenario states | rs_commissioned_officer_in_armed_forces_excluding_commissioned_warrant_officer |  |
| input active_service_compensation_as_commissioned_officer_excluding_pensions_and_retirement_pay | input | encoded | a name no rule defines -> a fact the scenario states | rs_active_service_compensation_as_commissioned_officer_excluding_pensions_and_retirement_pay |  |
| input maximum_enlisted_amount_for_commissioned_officer_months | input | encoded | a name no rule defines -> a fact the scenario states | rs_maximum_enlisted_amount_for_commissioned_officer_months |  |
| input armed_forces_member_in_missing_status_during_vietnam_conflict_as_result_of_conflict | input | encoded | a name no rule defines -> a fact the scenario states | rs_armed_forces_member_in_missing_status_during_vietnam_conflict_as_result_of_conflict |  |
| input officially_absent_from_post_of_duty_without_authority | input | encoded | a name no rule defines -> a fact the scenario states | rs_officially_absent_from_post_of_duty_without_authority |  |
| input armed_forces_missing_status_active_service_compensation | input | encoded | a name no rule defines -> a fact the scenario states | rs_armed_forces_missing_status_active_service_compensation |  |
| input civilian_employee_in_missing_status_during_vietnam_conflict_as_result_of_conflict | input | encoded | a name no rule defines -> a fact the scenario states | rs_civilian_employee_in_missing_status_during_vietnam_conflict_as_result_of_conflict |  |
| input civilian_employee_missing_status_active_service_compensation | input | encoded | a name no rule defines -> a fact the scenario states | rs_civilian_employee_missing_status_active_service_compensation |  |
| input employee_compensation_includible_in_gross_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_employee_compensation_includible_in_gross_income |  |
| input net_earnings_from_self_employment_after_self_employment_tax_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_net_earnings_from_self_employment_after_self_employment_tax_deduction |  |
| input pension_or_annuity_amount | input | encoded | a name no rule defines -> a fact the scenario states | rs_pension_or_annuity_amount |  |
| input nonresident_alien_income_not_connected_with_united_states_business | input | encoded | a name no rule defines -> a fact the scenario states | rs_nonresident_alien_income_not_connected_with_united_states_business |  |
| input penal_institution_service_compensation | input | encoded | a name no rule defines -> a fact the scenario states | rs_penal_institution_service_compensation |  |
| input subsidized_state_work_activity_service_compensation | input | encoded | a name no rule defines -> a fact the scenario states | rs_subsidized_state_work_activity_service_compensation |  |
| input taxpayer_elects_to_treat_section_112_excluded_amounts_as_earned_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_elects_to_treat_section_112_excluded_amounts_as_earned_income |  |
| input individual_is_child_of_taxpayer_or_descendant_of_such_child | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_is_child_of_taxpayer_or_descendant_of_such_child |  |
| input individual_is_sibling_stepsibling_or_descendant_of_such_relative | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_is_sibling_stepsibling_or_descendant_of_such_relative |  |
| input individual_is_permanently_and_totally_disabled | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_is_permanently_and_totally_disabled |  |
| input individual_is_younger_than_taxpayer | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_is_younger_than_taxpayer |  |
| input individual_age_at_close_of_calendar_year | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_age_at_close_of_calendar_year |  |
| input individual_is_student | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_is_student |  |
| input filing_status | input | encoded | a name no rule defines -> a fact the scenario states | rs_filing_status |  |
| input return_filed_only_for_claim_of_refund | input | encoded | a name no rule defines -> a fact the scenario states | rs_return_filed_only_for_claim_of_refund |  |
| input parents_filing_status | input | encoded | a name no rule defines -> a fact the scenario states | rs_parents_filing_status |  |
| input individual_principal_place_of_abode_with_taxpayer_fraction | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_principal_place_of_abode_with_taxpayer_fraction |  |
| input individual_own_support_fraction_provided_by_individual | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_own_support_fraction_provided_by_individual |  |
| input individual_may_be_claimed_as_qualifying_child_by_two_or_more_taxpayers | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_may_be_claimed_as_qualifying_child_by_two_or_more_taxpayers |  |
| input parents_of_individual_may_claim_individual_but_no_parent_claims | input | encoded | a name no rule defines -> a fact the scenario states | rs_parents_of_individual_may_claim_individual_but_no_parent_claims |  |
| input taxpayer_is_parent_of_individual | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_is_parent_of_individual |  |
| input taxpayer_adjusted_gross_income_higher_than_highest_parent_adjusted_gross_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_adjusted_gross_income_higher_than_highest_parent_adjusted_gross_income |  |
| input child_resided_with_taxpayer_parent_for_longest_period | input | encoded | a name no rule defines -> a fact the scenario states | rs_child_resided_with_taxpayer_parent_for_longest_period |  |
| input child_resided_with_both_parents_same_amount_of_time_and_taxpayer_parent_has_highest_adjusted_gross_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_child_resided_with_both_parents_same_amount_of_time_and_taxpayer_parent_has_highest_adjusted_gross_income |  |
| input no_parent_of_individual_is_a_claiming_taxpayer | input | encoded | a name no rule defines -> a fact the scenario states | rs_no_parent_of_individual_is_a_claiming_taxpayer |  |
| input taxpayer_has_highest_adjusted_gross_income_among_claiming_taxpayers | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_has_highest_adjusted_gross_income_among_claiming_taxpayers |  |
| input individual_is_qualified_individual | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_is_qualified_individual |  |
| input election_made_for_foreign_earned_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_election_made_for_foreign_earned_income |  |
| input foreign_earned_income_of_individual | input | encoded | a name no rule defines -> a fact the scenario states | rs_foreign_earned_income_of_individual |  |
| input election_made_for_housing_cost_amount | input | encoded | a name no rule defines -> a fact the scenario states | rs_election_made_for_housing_cost_amount |  |
| input housing_cost_amount_of_individual | input | encoded | a name no rule defines -> a fact the scenario states | rs_housing_cost_amount_of_individual |  |
| input possession_is_guam | input | encoded | a name no rule defines -> a fact the scenario states | rs_possession_is_guam |  |
| input possession_is_american_samoa | input | encoded | a name no rule defines -> a fact the scenario states | rs_possession_is_american_samoa |  |
| input possession_is_northern_mariana_islands | input | encoded | a name no rule defines -> a fact the scenario states | rs_possession_is_northern_mariana_islands |  |
| input bona_fide_resident_of_specified_possession_during_entire_taxable_year | input | encoded | a name no rule defines -> a fact the scenario states | rs_bona_fide_resident_of_specified_possession_during_entire_taxable_year |  |
| input income_derived_from_sources_within_specified_possessions | input | encoded | a name no rule defines -> a fact the scenario states | rs_income_derived_from_sources_within_specified_possessions |  |
| input income_effectively_connected_with_trade_or_business_within_specified_possessions | input | encoded | a name no rule defines -> a fact the scenario states | rs_income_effectively_connected_with_trade_or_business_within_specified_possessions |  |
| input amounts_paid_for_services_as_employee_of_united_states_or_agency | input | encoded | a name no rule defines -> a fact the scenario states | rs_amounts_paid_for_services_as_employee_of_united_states_or_agency |  |
| input deductions_other_than_section_151_before_section_931_denial | input | encoded | a name no rule defines -> a fact the scenario states | rs_deductions_other_than_section_151_before_section_931_denial |  |
| input deductions_properly_allocable_or_chargeable_to_amounts_excluded_under_section_931 | input | encoded | a name no rule defines -> a fact the scenario states | rs_deductions_properly_allocable_or_chargeable_to_amounts_excluded_under_section_931 |  |
| input credits_before_section_931_denial | input | encoded | a name no rule defines -> a fact the scenario states | rs_credits_before_section_931_denial |  |
| input credits_properly_allocable_or_chargeable_to_amounts_excluded_under_section_931 | input | encoded | a name no rule defines -> a fact the scenario states | rs_credits_properly_allocable_or_chargeable_to_amounts_excluded_under_section_931 |  |
| input individual_is_bona_fide_resident_of_puerto_rico_during_entire_taxable_year | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_is_bona_fide_resident_of_puerto_rico_during_entire_taxable_year |  |
| input income_derived_from_sources_within_puerto_rico | input | encoded | a name no rule defines -> a fact the scenario states | rs_income_derived_from_sources_within_puerto_rico |  |
| input amounts_received_for_services_performed_as_employee_of_united_states_or_agency | input | encoded | a name no rule defines -> a fact the scenario states | rs_amounts_received_for_services_performed_as_employee_of_united_states_or_agency |  |
| input individual_is_citizen_of_united_states | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_is_citizen_of_united_states |  |
| input individual_changes_residence_from_puerto_rico_during_taxable_year | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_changes_residence_from_puerto_rico_during_taxable_year |  |
| input bona_fide_resident_of_puerto_rico_years_before_change | input | encoded | a name no rule defines -> a fact the scenario states | rs_bona_fide_resident_of_puerto_rico_years_before_change |  |
| input puerto_rico_source_income_attributable_to_puerto_rican_residence_period_before_change | input | encoded | a name no rule defines -> a fact the scenario states | rs_puerto_rico_source_income_attributable_to_puerto_rican_residence_period_before_change |  |
| input amounts_received_for_services_performed_as_employee_of_united_states_or_agency_attributable_to_period_before_change | input | encoded | a name no rule defines -> a fact the scenario states | rs_amounts_received_for_services_performed_as_employee_of_united_states_or_agency_attributable_to_period_before_change |  |
| input deductions_other_than_section_151_before_section_933_denial | input | encoded | a name no rule defines -> a fact the scenario states | rs_deductions_other_than_section_151_before_section_933_denial |  |
| input deductions_other_than_section_151_properly_allocable_or_chargeable_to_amounts_excluded_under_section_933 | input | encoded | a name no rule defines -> a fact the scenario states | rs_deductions_other_than_section_151_properly_allocable_or_chargeable_to_amounts_excluded_under_section_933 |  |
| input credits_before_section_933_denial | input | encoded | a name no rule defines -> a fact the scenario states | rs_credits_before_section_933_denial |  |
| input credits_properly_allocable_or_chargeable_to_amounts_excluded_under_section_933 | input | encoded | a name no rule defines -> a fact the scenario states | rs_credits_properly_allocable_or_chargeable_to_amounts_excluded_under_section_933 |  |
| input taxable_year_begins_after_exemption_amount_zero_start | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxable_year_begins_after_exemption_amount_zero_start |  |
| input tin_included_on_return_claiming_exemption | input | encoded | a name no rule defines -> a fact the scenario states | rs_tin_included_on_return_claiming_exemption |  |
| input is_taxpayer | input | encoded | a name no rule defines -> a fact the scenario states | rs_is_taxpayer |  |
| input is_spouse_of_taxpayer | input | encoded | a name no rule defines -> a fact the scenario states | rs_is_spouse_of_taxpayer |  |
| input spouse_has_no_gross_income_for_calendar_year | input | encoded | a name no rule defines -> a fact the scenario states | rs_spouse_has_no_gross_income_for_calendar_year |  |
| input spouse_is_dependent_of_another_taxpayer | input | encoded | a name no rule defines -> a fact the scenario states | rs_spouse_is_dependent_of_another_taxpayer |  |
| input taxpayer_is_individual | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_is_individual |  |
| input qualified_individual_social_security_number_included_on_return | input | encoded | a name no rule defines -> a fact the scenario states | rs_qualified_individual_social_security_number_included_on_return |  |
| input age | input | encoded | a name no rule defines -> a fact the scenario states | rs_age |  |
| input adjusted_gross_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_adjusted_gross_income |  |
| input taxable_year_begins_before_senior_deduction_termination | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxable_year_begins_before_senior_deduction_termination |  |
| input spouse_dies_during_taxable_year | input | encoded | a name no rule defines -> a fact the scenario states | rs_spouse_dies_during_taxable_year |  |
| input taxpayer_married_at_time_of_spouse_death | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_married_at_time_of_spouse_death |  |
| input taxpayer_married_at_close_of_taxable_year | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_married_at_close_of_taxable_year |  |
| input legally_separated_under_decree_of_divorce_or_separate_maintenance | input | encoded | a name no rule defines -> a fact the scenario states | rs_legally_separated_under_decree_of_divorce_or_separate_maintenance |  |
| input person_is_child_within_federal_tax_child_definition | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_child_within_federal_tax_child_definition |  |
| input taxpayer_household_is_child_principal_place_of_abode | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_household_is_child_principal_place_of_abode |  |
| input child_principal_abode_fraction_of_taxable_year | input | encoded | a name no rule defines -> a fact the scenario states | rs_child_principal_abode_fraction_of_taxable_year |  |
| input would_be_entitled_to_child_deduction_but_for_parent_release_rule | input | encoded | a name no rule defines -> a fact the scenario states | rs_would_be_entitled_to_child_deduction_but_for_parent_release_rule |  |
| input taxpayer_files_separate_return | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_files_separate_return |  |
| input taxpayer_maintains_household_as_home | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_maintains_household_as_home |  |
| input taxpayer_household_cost_fraction_furnished | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_household_cost_fraction_furnished |  |
| input spouse_not_member_of_household_final_month_count | input | encoded | a name no rule defines -> a fact the scenario states | rs_spouse_not_member_of_household_final_month_count |  |
| input qualifying_child_principal_place_of_abode_is_in_united_states | input | encoded | a name no rule defines -> a fact the scenario states | rs_qualifying_child_principal_place_of_abode_is_in_united_states |  |
| input qualifying_child_name_age_and_tin_included_on_return | input | encoded | a name no rule defines -> a fact the scenario states | rs_qualifying_child_name_age_and_tin_included_on_return |  |
| input qualifying_child_marital_status_requires_section_151_entitlement | input | encoded | a name no rule defines -> a fact the scenario states | rs_qualifying_child_marital_status_requires_section_151_entitlement |  |
| input taxpayer_entitled_to_section_151_deduction_for_child_or_would_be_but_for_section_152_e | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_entitled_to_section_151_deduction_for_child_or_would_be_but_for_section_152_e |  |
| input childless_taxpayer_principal_place_of_abode_in_united_states_more_than_half_year | input | encoded | a name no rule defines -> a fact the scenario states | rs_childless_taxpayer_principal_place_of_abode_in_united_states_more_than_half_year |  |
| input childless_taxpayer_or_spouse_age_eligible_for_eitc | input | encoded | a name no rule defines -> a fact the scenario states | rs_childless_taxpayer_or_spouse_age_eligible_for_eitc |  |
| input taxpayer_is_dependent_for_section_151_to_another_taxpayer | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_is_dependent_for_section_151_to_another_taxpayer |  |
| input taxpayer_is_qualifying_child_of_another_taxpayer | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_is_qualifying_child_of_another_taxpayer |  |
| input taxpayer_claims_section_911_benefits | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_claims_section_911_benefits |  |
| input taxpayer_is_nonresident_alien_for_any_portion_of_year | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_is_nonresident_alien_for_any_portion_of_year |  |
| input taxpayer_treated_as_resident_by_section_6013_g_or_h_election | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_treated_as_resident_by_section_6013_g_or_h_election |  |
| input satisfies_eitc_separated_spouse_rules | input | encoded | a name no rule defines -> a fact the scenario states | rs_satisfies_eitc_separated_spouse_rules |  |
| input taxable_year_is_full_12_months | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxable_year_is_full_12_months |  |
| input taxable_year_closed_by_reason_of_taxpayer_death | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxable_year_closed_by_reason_of_taxpayer_death |  |
| input eitc_disallowance_period_applies | input | encoded | a name no rule defines -> a fact the scenario states | rs_eitc_disallowance_period_applies |  |
| input prior_deficiency_denial_without_required_eligibility_information | input | encoded | a name no rule defines -> a fact the scenario states | rs_prior_deficiency_denial_without_required_eligibility_information |  |
| input taxpayer_includes_required_social_security_number_on_return | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_includes_required_social_security_number_on_return |  |
| input spouse_includes_required_social_security_number_on_return | input | encoded | a name no rule defines -> a fact the scenario states | rs_spouse_includes_required_social_security_number_on_return |  |
| input eitc_relevant_investment_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_eitc_relevant_investment_income |  |
| section_911_amount_excluded_from_gross_income read by a rule of TaxUnit | entity | approximated | a value of Person read for a TaxUnit: the engine evaluates it for the same identifier, and so does the twin | rs_section_911_amount_excluded_from_gross_income |  |
| filing_status read by a rule of TaxUnit | entity | approximated | a value of Person read for a TaxUnit: the engine evaluates it for the same identifier, and so does the twin | rs_filing_status |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| one_child_phase_in_and_allowed | q_eitc | pass |  |
| one_child_phase_in_and_allowed | q_eitc_allowed | pass |  |
| one_child_phase_in_and_allowed | q_eitc_before_eligibility | pass |  |
| one_child_phase_in_and_allowed | q_eitc_capped_child_count | pass |  |
| one_child_phase_in_and_allowed | q_eitc_child_count | pass |  |
| one_child_phase_in_and_allowed | q_eitc_demographic_eligible | pass |  |
| one_child_phase_in_and_allowed | q_eitc_earned_income_amount | pass |  |
| one_child_phase_in_and_allowed | q_eitc_identification_requirements_satisfied | pass |  |
| one_child_phase_in_and_allowed | q_eitc_investment_income_eligible | pass |  |
| one_child_phase_in_and_allowed | q_eitc_maximum | pass |  |
| one_child_phase_in_and_allowed | q_eitc_phase_in_rate | pass |  |
| one_child_phase_in_and_allowed | q_eitc_phase_out_income | pass |  |
| one_child_phase_in_and_allowed | q_eitc_phase_out_rate | pass |  |
| one_child_phase_in_and_allowed | q_eitc_phase_out_start | pass |  |
| one_child_phase_in_and_allowed | q_eitc_phased_in | pass |  |
| one_child_phase_in_and_allowed | q_eitc_reduction | pass |  |
| one_child_phase_in_and_allowed | q_earned_income_before_section_112_election | pass |  |
| childless_person_age_predicate | q_eitc_childless_age_ceiling_exclusive | pass |  |
| childless_person_age_predicate | q_eitc_childless_age_eligible | pass |  |
| childless_person_age_predicate | q_eitc_childless_minimum_age | pass |  |
| qualifying_child_married_exception | q_eitc_qualifying_child | pass |  |
| qualifying_child_married_exception | q_eitc_qualifying_child_base | pass |  |
| qualifying_child_unmarried_allowed | q_eitc_qualifying_child | pass |  |
| qualifying_child_unmarried_allowed | q_eitc_qualifying_child_base | pass |  |
| investment_income_denies_credit | q_eitc | pass |  |
| investment_income_denies_credit | q_eitc_allowed | pass |  |
| investment_income_denies_credit | q_eitc_investment_income_eligible | pass |  |
| investment_income_denies_credit | q_earned_income_before_section_112_election | pass |  |

