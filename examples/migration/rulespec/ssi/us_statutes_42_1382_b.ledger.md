# Migration ledger: us_statutes_42_1382_b

Source: Axiom RuleSpec — sources/us/statutes/42/1382f/a.yaml, sources/us/statutes/42/1382/b.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-05
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 37 |
| approximated | 2 |
| residue | 0 |
| **total** | 39 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/42/1382f/a#annual_rounding_multiple | parameter | encoded | parameter -> a fact, cited | rs_annual_rounding_multiple |  |
| us:statutes/42/1382f/a#annual_rounding_multiple | parameter | encoded | rule | rs_annual_rounding_multiple |  |
| us:statutes/42/1382f/a#prior_rounding_carryover_increase | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_prior_rounding_carryover_increase |  |
| us:statutes/42/1382f/a#prior_rounding_carryover_increase | derived | encoded | rule | rs_prior_rounding_carryover_increase |  |
| us:statutes/42/1382f/a#amount_after_paragraph_1_increase | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_amount_after_paragraph_1_increase |  |
| us:statutes/42/1382f/a#amount_after_paragraph_1_increase | derived | encoded | rule | rs_amount_after_paragraph_1_increase |  |
| us:statutes/42/1382f/a#subsection_a_applicable_increase_percentage | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_subsection_a_applicable_increase_percentage |  |
| us:statutes/42/1382f/a#subsection_a_applicable_increase_percentage | derived | encoded | rule | rs_subsection_a_applicable_increase_percentage |  |
| us:statutes/42/1382f/a#amount_after_subsection_a_increase | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_amount_after_subsection_a_increase |  |
| us:statutes/42/1382f/a#amount_after_subsection_a_increase | derived | encoded | rule | rs_amount_after_subsection_a_increase |  |
| us:statutes/42/1382f/a#prior_rounding_carryover_increase_for_section_1382_b_1_amount | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_prior_rounding_carryover_increase_for_section_1382_b_1_amount |  |
| us:statutes/42/1382f/a#prior_rounding_carryover_increase_for_section_1382_b_1_amount | derived | encoded | rule | rs_prior_rounding_carryover_increase_for_section_1382_b_1_amount |  |
| us:statutes/42/1382f/a#amount_determined_under_section_1382f_for_section_1382_b_1 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_amount_determined_under_section_1382f_for_section_1382_b_1 |  |
| us:statutes/42/1382f/a#amount_determined_under_section_1382f_for_section_1382_b_1 | derived | encoded | rule | rs_amount_determined_under_section_1382f_for_section_1382_b_1 |  |
| us:statutes/42/1382f/a#prior_rounding_carryover_increase_for_section_1382_b_2_amount | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_prior_rounding_carryover_increase_for_section_1382_b_2_amount |  |
| us:statutes/42/1382f/a#prior_rounding_carryover_increase_for_section_1382_b_2_amount | derived | encoded | rule | rs_prior_rounding_carryover_increase_for_section_1382_b_2_amount |  |
| us:statutes/42/1382f/a#amount_determined_under_section_1382f_for_section_1382_b_2 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_amount_determined_under_section_1382f_for_section_1382_b_2 |  |
| us:statutes/42/1382f/a#amount_determined_under_section_1382f_for_section_1382_b_2 | derived | encoded | rule | rs_amount_determined_under_section_1382f_for_section_1382_b_2 |  |
| us:statutes/42/1382/b#statutory_base_annual_rate_without_eligible_spouse | parameter | encoded | parameter -> a fact, cited | rs_statutory_base_annual_rate_without_eligible_spouse |  |
| us:statutes/42/1382/b#statutory_base_annual_rate_without_eligible_spouse | parameter | encoded | rule | rs_statutory_base_annual_rate_without_eligible_spouse |  |
| us:statutes/42/1382/b#statutory_base_annual_rate_with_eligible_spouse | parameter | encoded | parameter -> a fact, cited | rs_statutory_base_annual_rate_with_eligible_spouse |  |
| us:statutes/42/1382/b#statutory_base_annual_rate_with_eligible_spouse | parameter | encoded | rule | rs_statutory_base_annual_rate_with_eligible_spouse |  |
| us:statutes/42/1382/b#annual_benefit_without_eligible_spouse | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_annual_benefit_without_eligible_spouse |  |
| us:statutes/42/1382/b#annual_benefit_without_eligible_spouse | derived | encoded | rule | rs_annual_benefit_without_eligible_spouse |  |
| us:statutes/42/1382/b#annual_benefit_with_eligible_spouse | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_annual_benefit_with_eligible_spouse |  |
| us:statutes/42/1382/b#annual_benefit_with_eligible_spouse | derived | encoded | rule | rs_annual_benefit_with_eligible_spouse |  |
| input unrounded_dollar_amount_that_would_have_been_in_effect_for_month_but_for_prior_rounding | input | encoded | a name no rule defines -> a fact the scenario states | rs_unrounded_dollar_amount_that_would_have_been_in_effect_for_month_but_for_prior_rounding |  |
| input dollar_amount_in_effect_for_month | input | encoded | a name no rule defines -> a fact the scenario states | rs_dollar_amount_in_effect_for_month |  |
| input subchapter_ii_increase_was_determined_on_wage_increase_percentage | input | encoded | a name no rule defines -> a fact the scenario states | rs_subchapter_ii_increase_was_determined_on_wage_increase_percentage |  |
| input subchapter_ii_benefit_increase_percentage_for_month | input | encoded | a name no rule defines -> a fact the scenario states | rs_subchapter_ii_benefit_increase_percentage_for_month |  |
| input cpi_basis_subchapter_ii_increase_percentage_for_month | input | encoded | a name no rule defines -> a fact the scenario states | rs_cpi_basis_subchapter_ii_increase_percentage_for_month |  |
| input unrounded_section_1382_b_1_dollar_amount_that_would_have_been_in_effect_for_month_but_for_prior_rounding | input | encoded | a name no rule defines -> a fact the scenario states | rs_unrounded_section_1382_b_1_dollar_amount_that_would_have_been_in_effect_for_month_but_for_prior_rounding |  |
| input section_1382_b_1_dollar_amount_in_effect_for_month | input | encoded | a name no rule defines -> a fact the scenario states | rs_section_1382_b_1_dollar_amount_in_effect_for_month |  |
| input unrounded_section_1382_b_2_dollar_amount_that_would_have_been_in_effect_for_month_but_for_prior_rounding | input | encoded | a name no rule defines -> a fact the scenario states | rs_unrounded_section_1382_b_2_dollar_amount_that_would_have_been_in_effect_for_month_but_for_prior_rounding |  |
| input section_1382_b_2_dollar_amount_in_effect_for_month | input | encoded | a name no rule defines -> a fact the scenario states | rs_section_1382_b_2_dollar_amount_in_effect_for_month |  |
| input individual_income_not_excluded_pursuant_to_section_1382a_b | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_income_not_excluded_pursuant_to_section_1382a_b |  |
| input individual_and_spouse_income_not_excluded_pursuant_to_section_1382a_b | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_and_spouse_income_not_excluded_pursuant_to_section_1382a_b |  |
| amount_determined_under_section_1382f_for_section_1382_b_1 read by a rule of Person | entity | approximated | a value of StatutoryDollarAmount read for a Person: the engine evaluates it for the same identifier, and so does the twin | rs_amount_determined_under_section_1382f_for_section_1382_b_1 |  |
| amount_determined_under_section_1382f_for_section_1382_b_2 read by a rule of Person | entity | approximated | a value of StatutoryDollarAmount read for a Person: the engine evaluates it for the same identifier, and so does the twin | rs_amount_determined_under_section_1382f_for_section_1382_b_2 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| base_rates_apply_when_section_1382f_amounts_are_lower | q_annual_benefit_with_eligible_spouse | pass |  |
| base_rates_apply_when_section_1382f_amounts_are_lower | q_annual_benefit_without_eligible_spouse | pass |  |
| section_1382f_amounts_apply_when_greater_than_statutory_base_rates | q_annual_benefit_with_eligible_spouse | pass |  |
| section_1382f_amounts_apply_when_greater_than_statutory_base_rates | q_annual_benefit_without_eligible_spouse | pass |  |
| income_reduction_cannot_make_payable_benefit_negative | q_annual_benefit_with_eligible_spouse | pass |  |
| income_reduction_cannot_make_payable_benefit_negative | q_annual_benefit_without_eligible_spouse | pass |  |

