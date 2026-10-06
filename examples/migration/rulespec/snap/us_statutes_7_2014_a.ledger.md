# Migration ledger: us_statutes_7_2014_a

Source: Axiom RuleSpec — sources/us/statutes/7/2014/a.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-06
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 10 |
| approximated | 0 |
| residue | 0 |
| **total** | 10 |

Fidelity: **12 of 12** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2014/a#household_meets_social_security_act_benefit_criterion | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_household_meets_social_security_act_benefit_criterion |  |
| us:statutes/7/2014/a#household_meets_qualifying_general_assistance_benefit_criterion | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_household_meets_qualifying_general_assistance_benefit_criterion |  |
| us:statutes/7/2014/a#household_has_snap_participation_basis_from_income_or_categorical_benefits | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_household_has_snap_participation_basis_from_income_or_categorical_benefits |  |
| input each_household_member_receives_benefits_under_state_program_funded_under_part_a_title_iv_social_security_act | input | encoded | a name no rule defines -> a fact the scenario states | rs_each_household_member_receives_benefits_under_state_program_funded_under_part_a_title_iv_social_security_act |  |
| input each_household_member_receives_supplemental_security_income_benefits_under_title_xvi_social_security_act | input | encoded | a name no rule defines -> a fact the scenario states | rs_each_household_member_receives_supplemental_security_income_benefits_under_title_xvi_social_security_act |  |
| input each_household_member_receives_aid_to_aged_blind_or_disabled_under_title_i_x_xiv_or_xvi_social_security_act | input | encoded | a name no rule defines -> a fact the scenario states | rs_each_household_member_receives_aid_to_aged_blind_or_disabled_under_title_i_x_xiv_or_xvi_social_security_act |  |
| input each_household_member_receives_benefits_under_state_or_local_general_assistance_program | input | encoded | a name no rule defines -> a fact the scenario states | rs_each_household_member_receives_benefits_under_state_or_local_general_assistance_program |  |
| input state_or_local_general_assistance_program_uses_income_criteria_comparable_to_or_more_restrictive_than_subsection_c_2 | input | encoded | a name no rule defines -> a fact the scenario states | rs_state_or_local_general_assistance_program_uses_income_criteria_comparable_to_or_more_restrictive_than_subsection_c_2 |  |
| input state_or_local_general_assistance_program_is_not_limited_to_one_time_emergency_payments_unavailable_for_more_than_one_consecutive_month | input | encoded | a name no rule defines -> a fact the scenario states | rs_state_or_local_general_assistance_program_is_not_limited_to_one_time_emergency_payments_unavailable_for_more_than_one_consecutive_month |  |
| input household_income_and_other_financial_resources_are_substantial_limiting_factor_in_permitting_more_nutritious_diet | input | encoded | a name no rule defines -> a fact the scenario states | rs_household_income_and_other_financial_resources_are_substantial_limiting_factor_in_permitting_more_nutritious_diet |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| no_income_or_categorical_basis | q_household_has_snap_participation_basis_from_income_or_categorical_benefits | pass |  |
| no_income_or_categorical_basis | q_household_meets_qualifying_general_assistance_benefit_criterion | pass |  |
| no_income_or_categorical_basis | q_household_meets_social_security_act_benefit_criterion | pass |  |
| substantial_limiting_factor_basis | q_household_has_snap_participation_basis_from_income_or_categorical_benefits | pass |  |
| substantial_limiting_factor_basis | q_household_meets_qualifying_general_assistance_benefit_criterion | pass |  |
| substantial_limiting_factor_basis | q_household_meets_social_security_act_benefit_criterion | pass |  |
| supplemental_security_income_categorical_basis | q_household_has_snap_participation_basis_from_income_or_categorical_benefits | pass |  |
| supplemental_security_income_categorical_basis | q_household_meets_qualifying_general_assistance_benefit_criterion | pass |  |
| supplemental_security_income_categorical_basis | q_household_meets_social_security_act_benefit_criterion | pass |  |
| qualifying_general_assistance_categorical_basis | q_household_has_snap_participation_basis_from_income_or_categorical_benefits | pass |  |
| qualifying_general_assistance_categorical_basis | q_household_meets_qualifying_general_assistance_benefit_criterion | pass |  |
| qualifying_general_assistance_categorical_basis | q_household_meets_social_security_act_benefit_criterion | pass |  |

