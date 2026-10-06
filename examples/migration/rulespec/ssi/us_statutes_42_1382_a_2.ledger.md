# Migration ledger: us_statutes_42_1382_a_2

Source: Axiom RuleSpec — sources/us/statutes/42/1382c/a/1.yaml, sources/us/statutes/42/1382/a/3.yaml, sources/us/statutes/42/1382f/a.yaml, sources/us/statutes/42/1382/a/2.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-06
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 40 |
| approximated | 1 |
| residue | 0 |
| **total** | 41 |

Fidelity: **5 of 5** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/42/1382c/a/1#aged_age_threshold_years | parameter | encoded | parameter -> a fact, cited | rs_aged_age_threshold_years |  |
| us:statutes/42/1382c/a/1#aged_blind_or_disabled_individual | derived | encoded | derived judgment -> a rule concluding a sentence | rs_aged_blind_or_disabled_individual |  |
| us:statutes/42/1382/a/3#resource_limit_amount_for_paragraph_1_B_i_and_paragraph_2_B | parameter | encoded | parameter -> a fact, cited, 6 version(s) guarded by the calculation date | rs_resource_limit_amount_for_paragraph_1_B_i_and_paragraph_2_B |  |
| us:statutes/42/1382/a/3#resource_limit_amount_for_paragraph_1_B_ii | parameter | encoded | parameter -> a fact, cited, 6 version(s) guarded by the calculation date | rs_resource_limit_amount_for_paragraph_1_B_ii |  |
| us:statutes/42/1382/a/3#couple_or_living_with_spouse_resource_limit | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_couple_or_living_with_spouse_resource_limit |  |
| us:statutes/42/1382/a/3#individual_no_spouse_resource_limit | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_individual_no_spouse_resource_limit |  |
| us:statutes/42/1382f/a#annual_rounding_multiple | parameter | encoded | parameter -> a fact, cited | rs_annual_rounding_multiple |  |
| us:statutes/42/1382f/a#prior_rounding_carryover_increase | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_prior_rounding_carryover_increase |  |
| us:statutes/42/1382f/a#amount_after_paragraph_1_increase | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_amount_after_paragraph_1_increase |  |
| us:statutes/42/1382f/a#subsection_a_applicable_increase_percentage | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_subsection_a_applicable_increase_percentage |  |
| us:statutes/42/1382f/a#amount_after_subsection_a_increase | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_amount_after_subsection_a_increase |  |
| us:statutes/42/1382f/a#prior_rounding_carryover_increase_for_section_1382_b_1_amount | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_prior_rounding_carryover_increase_for_section_1382_b_1_amount |  |
| us:statutes/42/1382f/a#amount_determined_under_section_1382f_for_section_1382_b_1 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_amount_determined_under_section_1382f_for_section_1382_b_1 |  |
| us:statutes/42/1382f/a#prior_rounding_carryover_increase_for_section_1382_b_2_amount | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_prior_rounding_carryover_increase_for_section_1382_b_2_amount |  |
| us:statutes/42/1382f/a#amount_determined_under_section_1382f_for_section_1382_b_2 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_amount_determined_under_section_1382f_for_section_1382_b_2 |  |
| us:statutes/42/1382/a/2#couple_annual_income_base_limit | parameter | encoded | parameter -> a fact, cited | rs_couple_annual_income_base_limit |  |
| us:statutes/42/1382/a/2#applicable_couple_annual_income_limit | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_applicable_couple_annual_income_limit |  |
| us:statutes/42/1382/a/2#eligible_individual_with_eligible_spouse | derived | encoded | derived judgment -> a rule concluding a sentence | rs_eligible_individual_with_eligible_spouse |  |
| input individual_age_years | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_age_years |  |
| input blind_as_determined_under_paragraph_2 | input | encoded | a name no rule defines -> a fact the scenario states | rs_blind_as_determined_under_paragraph_2 |  |
| input disabled_as_determined_under_paragraph_3 | input | encoded | a name no rule defines -> a fact the scenario states | rs_disabled_as_determined_under_paragraph_3 |  |
| input resident_of_united_states | input | encoded | a name no rule defines -> a fact the scenario states | rs_resident_of_united_states |  |
| input citizen_of_united_states | input | encoded | a name no rule defines -> a fact the scenario states | rs_citizen_of_united_states |  |
| input alien_lawfully_admitted_for_permanent_residence | input | encoded | a name no rule defines -> a fact the scenario states | rs_alien_lawfully_admitted_for_permanent_residence |  |
| input alien_otherwise_permanently_residing_in_united_states_under_color_of_law | input | encoded | a name no rule defines -> a fact the scenario states | rs_alien_otherwise_permanently_residing_in_united_states_under_color_of_law |  |
| input alien_lawfully_present_due_to_section_1182_d_5_application | input | encoded | a name no rule defines -> a fact the scenario states | rs_alien_lawfully_present_due_to_section_1182_d_5_application |  |
| input child_citizen_of_united_states | input | encoded | a name no rule defines -> a fact the scenario states | rs_child_citizen_of_united_states |  |
| input living_with_parent_member_of_armed_forces_assigned_to_permanent_duty_ashore_outside_united_states | input | encoded | a name no rule defines -> a fact the scenario states | rs_living_with_parent_member_of_armed_forces_assigned_to_permanent_duty_ashore_outside_united_states |  |
| input unrounded_dollar_amount_that_would_have_been_in_effect_for_month_but_for_prior_rounding | input | encoded | a name no rule defines -> a fact the scenario states | rs_unrounded_dollar_amount_that_would_have_been_in_effect_for_month_but_for_prior_rounding |  |
| input dollar_amount_in_effect_for_month | input | encoded | a name no rule defines -> a fact the scenario states | rs_dollar_amount_in_effect_for_month |  |
| input subchapter_ii_increase_was_determined_on_wage_increase_percentage | input | encoded | a name no rule defines -> a fact the scenario states | rs_subchapter_ii_increase_was_determined_on_wage_increase_percentage |  |
| input subchapter_ii_benefit_increase_percentage_for_month | input | encoded | a name no rule defines -> a fact the scenario states | rs_subchapter_ii_benefit_increase_percentage_for_month |  |
| input cpi_basis_subchapter_ii_increase_percentage_for_month | input | encoded | a name no rule defines -> a fact the scenario states | rs_cpi_basis_subchapter_ii_increase_percentage_for_month |  |
| input unrounded_section_1382_b_1_dollar_amount_that_would_have_been_in_effect_for_month_but_for_prior_rounding | input | encoded | a name no rule defines -> a fact the scenario states | rs_unrounded_section_1382_b_1_dollar_amount_that_would_have_been_in_effect_for_month_but_for_prior_rounding |  |
| input section_1382_b_1_dollar_amount_in_effect_for_month | input | encoded | a name no rule defines -> a fact the scenario states | rs_section_1382_b_1_dollar_amount_in_effect_for_month |  |
| input unrounded_section_1382_b_2_dollar_amount_that_would_have_been_in_effect_for_month_but_for_prior_rounding | input | encoded | a name no rule defines -> a fact the scenario states | rs_unrounded_section_1382_b_2_dollar_amount_that_would_have_been_in_effect_for_month_but_for_prior_rounding |  |
| input section_1382_b_2_dollar_amount_in_effect_for_month | input | encoded | a name no rule defines -> a fact the scenario states | rs_section_1382_b_2_dollar_amount_in_effect_for_month |  |
| input individual_has_eligible_spouse | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_has_eligible_spouse |  |
| input combined_annual_income_other_than_excluded_pursuant_to_section_1382a_b | input | encoded | a name no rule defines -> a fact the scenario states | rs_combined_annual_income_other_than_excluded_pursuant_to_section_1382a_b |  |
| input combined_resources_other_than_excluded_pursuant_to_section_1382b_a | input | encoded | a name no rule defines -> a fact the scenario states | rs_combined_resources_other_than_excluded_pursuant_to_section_1382b_a |  |
| amount_after_subsection_a_increase read by a rule of Person | entity | approximated | a value of StatutoryDollarAmount read for a Person: the engine evaluates it for the same identifier, and so does the twin | rs_amount_after_subsection_a_increase |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| aged_citizen_with_eligible_spouse_income_and_resources_within_limits_qualifies | q_applicable_couple_annual_income_limit | pass |  |
| aged_citizen_with_eligible_spouse_income_and_resources_within_limits_qualifies | q_eligible_individual_with_eligible_spouse | pass |  |
| no_eligible_spouse_does_not_qualify_under_couple_branch | q_eligible_individual_with_eligible_spouse | pass |  |
| combined_income_above_applicable_couple_limit_does_not_qualify | q_eligible_individual_with_eligible_spouse | pass |  |
| combined_resources_above_paragraph_3_amount_does_not_qualify | q_eligible_individual_with_eligible_spouse | pass |  |

