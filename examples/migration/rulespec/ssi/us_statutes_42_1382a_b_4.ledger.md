# Migration ledger: us_statutes_42_1382a_b_4

Source: Axiom RuleSpec — sources/us/statutes/42/1382a/b/4.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-05
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 24 |
| approximated | 0 |
| residue | 0 |
| **total** | 24 |

Fidelity: **20 of 20** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/42/1382a/b/4#annual_earned_income_initial_exclusion_limit | parameter | encoded | parameter -> a fact, cited | rs_annual_earned_income_initial_exclusion_limit |  |
| us:statutes/42/1382a/b/4#annual_earned_income_initial_exclusion_limit | parameter | encoded | rule | rs_annual_earned_income_initial_exclusion_limit |  |
| us:statutes/42/1382a/b/4#earned_income_remainder_exclusion_rate | parameter | encoded | parameter -> a fact, cited | rs_earned_income_remainder_exclusion_rate |  |
| us:statutes/42/1382a/b/4#earned_income_remainder_exclusion_rate | parameter | encoded | rule | rs_earned_income_remainder_exclusion_rate |  |
| us:statutes/42/1382a/b/4#blind_branch_earned_income_excluded | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_blind_branch_earned_income_excluded |  |
| us:statutes/42/1382a/b/4#blind_branch_earned_income_excluded | derived | encoded | rule | rs_blind_branch_earned_income_excluded |  |
| us:statutes/42/1382a/b/4#blind_branch_earning_expenses_excluded | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_blind_branch_earning_expenses_excluded |  |
| us:statutes/42/1382a/b/4#blind_branch_earning_expenses_excluded | derived | encoded | rule | rs_blind_branch_earning_expenses_excluded |  |
| us:statutes/42/1382a/b/4#blind_branch_self_support_plan_other_income_excluded | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_blind_branch_self_support_plan_other_income_excluded |  |
| us:statutes/42/1382a/b/4#blind_branch_self_support_plan_other_income_excluded | derived | encoded | rule | rs_blind_branch_self_support_plan_other_income_excluded |  |
| us:statutes/42/1382a/b/4#disabled_branch_earned_income_excluded | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_disabled_branch_earned_income_excluded |  |
| us:statutes/42/1382a/b/4#disabled_branch_earned_income_excluded | derived | encoded | rule | rs_disabled_branch_earned_income_excluded |  |
| us:statutes/42/1382a/b/4#disabled_branch_self_support_plan_other_income_excluded | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_disabled_branch_self_support_plan_other_income_excluded |  |
| us:statutes/42/1382a/b/4#disabled_branch_self_support_plan_other_income_excluded | derived | encoded | rule | rs_disabled_branch_self_support_plan_other_income_excluded |  |
| us:statutes/42/1382a/b/4#age_sixty_five_branch_earned_income_excluded | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_age_sixty_five_branch_earned_income_excluded |  |
| us:statutes/42/1382a/b/4#age_sixty_five_branch_earned_income_excluded | derived | encoded | rule | rs_age_sixty_five_branch_earned_income_excluded |  |
| input individual_or_spouse_satisfies_blind_branch_status_condition | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_or_spouse_satisfies_blind_branch_status_condition |  |
| input earned_income_not_excluded_by_preceding_paragraphs | input | encoded | a name no rule defines -> a fact the scenario states | rs_earned_income_not_excluded_by_preceding_paragraphs |  |
| input expenses_reasonably_attributable_to_earning_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_expenses_reasonably_attributable_to_earning_income |  |
| input individual_has_commissioner_approved_plan_for_achieving_self_support | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_has_commissioner_approved_plan_for_achieving_self_support |  |
| input other_income_amount_necessary_for_fulfillment_of_self_support_plan | input | encoded | a name no rule defines -> a fact the scenario states | rs_other_income_amount_necessary_for_fulfillment_of_self_support_plan |  |
| input individual_or_spouse_satisfies_disabled_not_blind_branch_status_condition | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_or_spouse_satisfies_disabled_not_blind_branch_status_condition |  |
| input disability_work_expense_amount_necessary_and_within_commissioner_limits | input | encoded | a name no rule defines -> a fact the scenario states | rs_disability_work_expense_amount_necessary_and_within_commissioner_limits |  |
| input individual_or_spouse_has_attained_age_sixty_five_and_is_not_included_under_subparagraph_a_or_b | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_or_spouse_has_attained_age_sixty_five_and_is_not_included_under_subparagraph_a_or_b |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| blind_branch_excludes_initial_amount_remainder_expenses_and_pass_other_income | q_age_sixty_five_branch_earned_income_excluded | pass |  |
| blind_branch_excludes_initial_amount_remainder_expenses_and_pass_other_income | q_blind_branch_earned_income_excluded | pass |  |
| blind_branch_excludes_initial_amount_remainder_expenses_and_pass_other_income | q_blind_branch_earning_expenses_excluded | pass |  |
| blind_branch_excludes_initial_amount_remainder_expenses_and_pass_other_income | q_blind_branch_self_support_plan_other_income_excluded | pass |  |
| blind_branch_excludes_initial_amount_remainder_expenses_and_pass_other_income | q_disabled_branch_earned_income_excluded | pass |  |
| blind_branch_excludes_initial_amount_remainder_expenses_and_pass_other_income | q_disabled_branch_self_support_plan_other_income_excluded | pass |  |
| disabled_branch_excludes_initial_amount_work_expenses_and_half_remaining | q_age_sixty_five_branch_earned_income_excluded | pass |  |
| disabled_branch_excludes_initial_amount_work_expenses_and_half_remaining | q_blind_branch_earned_income_excluded | pass |  |
| disabled_branch_excludes_initial_amount_work_expenses_and_half_remaining | q_blind_branch_earning_expenses_excluded | pass |  |
| disabled_branch_excludes_initial_amount_work_expenses_and_half_remaining | q_blind_branch_self_support_plan_other_income_excluded | pass |  |
| disabled_branch_excludes_initial_amount_work_expenses_and_half_remaining | q_disabled_branch_earned_income_excluded | pass |  |
| disabled_branch_excludes_initial_amount_work_expenses_and_half_remaining | q_disabled_branch_self_support_plan_other_income_excluded | pass |  |
| age_sixty_five_branch_excludes_initial_amount_and_half_remainder | q_age_sixty_five_branch_earned_income_excluded | pass |  |
| age_sixty_five_branch_excludes_initial_amount_and_half_remainder | q_blind_branch_earned_income_excluded | pass |  |
| age_sixty_five_branch_excludes_initial_amount_and_half_remainder | q_blind_branch_earning_expenses_excluded | pass |  |
| age_sixty_five_branch_excludes_initial_amount_and_half_remainder | q_blind_branch_self_support_plan_other_income_excluded | pass |  |
| age_sixty_five_branch_excludes_initial_amount_and_half_remainder | q_disabled_branch_earned_income_excluded | pass |  |
| age_sixty_five_branch_excludes_initial_amount_and_half_remainder | q_disabled_branch_self_support_plan_other_income_excluded | pass |  |
| oracle_parameter_annual_earned_income_initial_exclusion_limit | q_annual_earned_income_initial_exclusion_limit | pass |  |
| oracle_parameter_earned_income_remainder_exclusion_rate | q_earned_income_remainder_exclusion_rate | pass |  |

