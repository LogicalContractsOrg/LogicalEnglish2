# Migration ledger: us_statutes_42_1382a_b_2

Source: Axiom RuleSpec — sources/us/statutes/42/1382a/b/2.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-06
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 15 |
| approximated | 0 |
| residue | 0 |
| **total** | 15 |

Fidelity: **5 of 5** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/42/1382a/b/2#annual_general_income_exclusion_limit | parameter | encoded | parameter -> a fact, cited | rs_annual_general_income_exclusion_limit |  |
| us:statutes/42/1382a/b/2#default_state_age_payment_age | parameter | encoded | parameter -> a fact, cited | rs_default_state_age_payment_age |  |
| us:statutes/42/1382a/b/2#state_age_payment_residency_year_requirement | parameter | encoded | parameter -> a fact, cited | rs_state_age_payment_residency_year_requirement |  |
| us:statutes/42/1382a/b/2#annual_general_income_excluded | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_annual_general_income_excluded |  |
| us:statutes/42/1382a/b/2#state_age_residency_payment_excluded | derived | encoded | derived judgment -> a rule concluding a sentence | rs_state_age_residency_payment_excluded |  |
| input annual_income_not_paid_on_basis_of_need | input | encoded | a name no rule defines -> a fact the scenario states | rs_annual_income_not_paid_on_basis_of_need |  |
| input payment_is_monthly_or_other_periodic | input | encoded | a name no rule defines -> a fact the scenario states | rs_payment_is_monthly_or_other_periodic |  |
| input payment_received_by_individual | input | encoded | a name no rule defines -> a fact the scenario states | rs_payment_received_by_individual |  |
| input program_established_prior_to_july_first_nineteen_seventy_three | input | encoded | a name no rule defines -> a fact the scenario states | rs_program_established_prior_to_july_first_nineteen_seventy_three |  |
| input program_established_prior_to_july_first_nineteen_seventy_three_and_subsequently_amended_to_conform_to_state_or_federal_constitutional_standards | input | encoded | a name no rule defines -> a fact the scenario states | rs_program_established_prior_to_july_first_nineteen_seventy_three_and_subsequently_amended_to_conform_to_state_or_federal_constitutional_standards |  |
| input payment_made_by_state_of_which_receiving_individual_is_resident | input | encoded | a name no rule defines -> a fact the scenario states | rs_payment_made_by_state_of_which_receiving_individual_is_resident |  |
| input payment_program_eligibility_not_based_on_need | input | encoded | a name no rule defines -> a fact the scenario states | rs_payment_program_eligibility_not_based_on_need |  |
| input payment_program_eligibility_based_solely_on_required_age_and_state_residency | input | encoded | a name no rule defines -> a fact the scenario states | rs_payment_program_eligibility_based_solely_on_required_age_and_state_residency |  |
| input individual_first_became_eligible_individual_or_eligible_spouse_on_or_before_september_thirtieth_nineteen_eighty_five | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_first_became_eligible_individual_or_eligible_spouse_on_or_before_september_thirtieth_nineteen_eighty_five |  |
| input individual_residency_years_under_program_as_in_effect_prior_to_january_first_nineteen_eighty_three | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_residency_years_under_program_as_in_effect_prior_to_january_first_nineteen_eighty_three |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| annual_general_income_exclusion_capped_at_240 | q_annual_general_income_excluded | pass |  |
| annual_general_income_exclusion_uses_lower_non_need_income | q_annual_general_income_excluded | pass |  |
| qualifying_state_age_residency_payment_is_excluded | q_state_age_residency_payment_excluded | pass |  |
| state_age_residency_payment_not_excluded_when_need_based | q_state_age_residency_payment_excluded | pass |  |
| oracle_parameter_annual_general_income_exclusion_limit | q_annual_general_income_exclusion_limit | pass |  |

