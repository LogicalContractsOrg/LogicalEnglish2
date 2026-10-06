# Migration ledger: us_statutes_26_32_c_2

Source: Axiom RuleSpec — sources/us/statutes/26/112.yaml, sources/us/statutes/26/32/c/2.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-06
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 25 |
| approximated | 0 |
| residue | 0 |
| **total** | 25 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/26/112#hospitalization_after_combat_zone_termination_limit_years | parameter | encoded | parameter -> a fact, cited | rs_hospitalization_after_combat_zone_termination_limit_years |  |
| us:statutes/26/112#amount_excluded_from_gross_income_by_reason_of_section_112 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_amount_excluded_from_gross_income_by_reason_of_section_112 |  |
| us:statutes/26/32/c/2#earned_income_before_section_112_election | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_earned_income_before_section_112_election |  |
| us:statutes/26/32/c/2#earned_income | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_earned_income |  |
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

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| employee_compensation_plus_self_employment_earnings | q_earned_income | pass |  |
| explicit_exclusions_reduce_earned_income | q_earned_income | pass |  |
| section_112_election_adds_excluded_combat_zone_amount | q_earned_income | pass |  |
| auto_output_earned_income_before_section_112_election | q_earned_income_before_section_112_election | pass |  |

