# Migration ledger: us_statutes_26_24

Source: Axiom RuleSpec — sources/us/statutes/26/24/h.yaml, sources/us/statutes/26/24.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-07
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 70 |
| approximated | 0 |
| residue | 0 |
| **total** | 70 |

Fidelity: **28 of 28** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/26/24/h#dependent_of_tax_unit | data_relation | encoded | data relation -> a two-place sentence the scenario states | rs_dependent_of_tax_unit |  |
| us:statutes/26/24/h#ctc_child_amount_under_subsection_h | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_child_amount_under_subsection_h |  |
| us:statutes/26/24/h#ctc_joint_phase_out_threshold_under_subsection_h | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_joint_phase_out_threshold_under_subsection_h |  |
| us:statutes/26/24/h#ctc_other_phase_out_threshold_under_subsection_h | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_other_phase_out_threshold_under_subsection_h |  |
| us:statutes/26/24/h#ctc_other_dependent_amount_under_subsection_h | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_other_dependent_amount_under_subsection_h |  |
| us:statutes/26/24/h#ctc_refundable_per_child_cap_under_subsection_h | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_refundable_per_child_cap_under_subsection_h |  |
| us:statutes/26/24/h#ctc_refundable_phase_in_threshold_under_subsection_h | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_refundable_phase_in_threshold_under_subsection_h |  |
| us:statutes/26/24/h#ctc_child_ssn_requirement_satisfied_under_subsection_h | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_ctc_child_ssn_requirement_satisfied_under_subsection_h |  |
| us:statutes/26/24/h#ctc_child_credit_disallowed_by_ssn_requirement_under_subsection_h | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_ctc_child_credit_disallowed_by_ssn_requirement_under_subsection_h |  |
| us:statutes/26/24/h#ctc_qualifying_child_under_subsection_h | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_ctc_qualifying_child_under_subsection_h |  |
| us:statutes/26/24/h#ctc_other_dependent_under_subsection_h | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_ctc_other_dependent_under_subsection_h |  |
| us:statutes/26/24/h#ctc_qualifying_children_under_subsection_h | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_ctc_qualifying_children_under_subsection_h |  |
| us:statutes/26/24/h#ctc_other_dependents_under_subsection_h | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_ctc_other_dependents_under_subsection_h |  |
| us:statutes/26/24/h#ctc_phase_out_threshold_under_subsection_h | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_ctc_phase_out_threshold_under_subsection_h |  |
| us:statutes/26/24/h#ctc_maximum_before_phase_out_under_subsection_h | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_ctc_maximum_before_phase_out_under_subsection_h |  |
| us:statutes/26/24/h#ctc_refundable_maximum_under_subsection_h | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_ctc_refundable_maximum_under_subsection_h |  |
| us:statutes/26/24#ctc_qualifying_child_of_tax_unit | data_relation | encoded | data relation -> a two-place sentence the scenario states | rs_ctc_qualifying_child_of_tax_unit |  |
| us:statutes/26/24#ctc_child_amount_base | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_child_amount_base |  |
| us:statutes/26/24#ctc_phaseout_reduction_per_increment | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_phaseout_reduction_per_increment |  |
| us:statutes/26/24#ctc_phaseout_increment | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_phaseout_increment |  |
| us:statutes/26/24#ctc_joint_threshold_base | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_joint_threshold_base |  |
| us:statutes/26/24#ctc_unmarried_threshold_base | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_unmarried_threshold_base |  |
| us:statutes/26/24#ctc_separate_threshold_base | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_separate_threshold_base |  |
| us:statutes/26/24#ctc_child_age_ceiling_exclusive | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_child_age_ceiling_exclusive |  |
| us:statutes/26/24#ctc_full_taxable_year_months | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_full_taxable_year_months |  |
| us:statutes/26/24#ctc_fraud_disallowance_years | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_fraud_disallowance_years |  |
| us:statutes/26/24#ctc_reckless_disallowance_years | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_ctc_reckless_disallowance_years |  |
| us:statutes/26/24#ctc_modified_adjusted_gross_income | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_ctc_modified_adjusted_gross_income |  |
| us:statutes/26/24#ctc_qualifying_child | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_ctc_qualifying_child |  |
| us:statutes/26/24#ctc_child_identification_requirement_satisfied | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_ctc_child_identification_requirement_satisfied |  |
| us:statutes/26/24#ctc_qualifying_children_count | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_ctc_qualifying_children_count |  |
| us:statutes/26/24#ctc_taxpayer_identification_requirement_satisfied | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_ctc_taxpayer_identification_requirement_satisfied |  |
| us:statutes/26/24#ctc_full_taxable_year_requirement_satisfied | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_ctc_full_taxable_year_requirement_satisfied |  |
| us:statutes/26/24#ctc_prior_claim_restriction_satisfied | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_ctc_prior_claim_restriction_satisfied |  |
| us:statutes/26/24#ctc_phaseout_threshold_base | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_ctc_phaseout_threshold_base |  |
| us:statutes/26/24#ctc_phaseout_threshold | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_ctc_phaseout_threshold |  |
| us:statutes/26/24#ctc_maximum_before_phaseout | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_ctc_maximum_before_phaseout |  |
| us:statutes/26/24#ctc_phaseout_amount | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_ctc_phaseout_amount |  |
| us:statutes/26/24#ctc_before_advance_payments | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_ctc_before_advance_payments |  |
| us:statutes/26/24#ctc_after_advance_payments | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_ctc_after_advance_payments |  |
| input taxpayer_or_spouse_ssn_included_on_return | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_or_spouse_ssn_included_on_return |  |
| input qualifying_child_ssn_included_on_return | input | encoded | a name no rule defines -> a fact the scenario states | rs_qualifying_child_ssn_included_on_return |  |
| input taxpayer_or_spouse_ssn_is_valid_for_subsection_h | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_or_spouse_ssn_is_valid_for_subsection_h |  |
| input qualifying_child_ssn_is_valid_for_subsection_h | input | encoded | a name no rule defines -> a fact the scenario states | rs_qualifying_child_ssn_is_valid_for_subsection_h |  |
| input ctc_child_satisfies_subsection_c | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_child_satisfies_subsection_c |  |
| input ctc_person_satisfies_dependency_rules | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_person_satisfies_dependency_rules |  |
| input noncitizen_exception_to_other_dependent_credit_under_subsection_h | input | encoded | a name no rule defines -> a fact the scenario states | rs_noncitizen_exception_to_other_dependent_credit_under_subsection_h |  |
| input filing_status | input | encoded | a name no rule defines -> a fact the scenario states | rs_filing_status |  |
| input adjusted_gross_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_adjusted_gross_income |  |
| input ctc_foreign_earned_income_exclusion_adjustment | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_foreign_earned_income_exclusion_adjustment |  |
| input ctc_possession_income_exclusion_adjustment | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_possession_income_exclusion_adjustment |  |
| input ctc_puerto_rico_income_exclusion_adjustment | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_puerto_rico_income_exclusion_adjustment |  |
| input ctc_child_satisfies_dependency_rules | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_child_satisfies_dependency_rules |  |
| input age | input | encoded | a name no rule defines -> a fact the scenario states | rs_age |  |
| input ctc_child_deduction_allowed | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_child_deduction_allowed |  |
| input certain_noncitizen_exception_applies | input | encoded | a name no rule defines -> a fact the scenario states | rs_certain_noncitizen_exception_applies |  |
| input qualifying_child_name_included_on_return | input | encoded | a name no rule defines -> a fact the scenario states | rs_qualifying_child_name_included_on_return |  |
| input qualifying_child_tin_included_on_return | input | encoded | a name no rule defines -> a fact the scenario states | rs_qualifying_child_tin_included_on_return |  |
| input qualifying_child_tin_issued_on_or_before_return_due_date | input | encoded | a name no rule defines -> a fact the scenario states | rs_qualifying_child_tin_issued_on_or_before_return_due_date |  |
| input ctc_child_missing_identification | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_child_missing_identification |  |
| input taxpayer_identification_number_issued_after_return_due_date | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_identification_number_issued_after_return_due_date |  |
| input taxable_year_months | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxable_year_months |  |
| input taxable_year_closed_by_reason_of_taxpayer_death | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxable_year_closed_by_reason_of_taxpayer_death |  |
| input ctc_fraud_disallowance_period_applies | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_fraud_disallowance_period_applies |  |
| input ctc_reckless_or_intentional_disregard_disallowance_period_applies | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_reckless_or_intentional_disregard_disallowance_period_applies |  |
| input prior_deficiency_denial_without_required_eligibility_information | input | encoded | a name no rule defines -> a fact the scenario states | rs_prior_deficiency_denial_without_required_eligibility_information |  |
| input ctc_phaseout_joint_threshold_applies | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_phaseout_joint_threshold_applies |  |
| input ctc_phaseout_separate_threshold_applies | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_phaseout_separate_threshold_applies |  |
| input ctc_subsection_h_special_rules_apply | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_subsection_h_special_rules_apply |  |
| input ctc_advance_payments_received | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_advance_payments_received |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| qualifying_child_person_positive_and_identification | q_ctc_child_age_ceiling_exclusive | pass |  |
| qualifying_child_person_positive_and_identification | q_ctc_child_identification_requirement_satisfied | pass |  |
| qualifying_child_person_positive_and_identification | q_ctc_qualifying_child | pass |  |
| qualifying_child_noncitizen_exception_not_holds | q_ctc_child_identification_requirement_satisfied | pass |  |
| qualifying_child_noncitizen_exception_not_holds | q_ctc_qualifying_child | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_after_advance_payments | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_before_advance_payments | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_child_amount_base | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_fraud_disallowance_years | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_full_taxable_year_months | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_full_taxable_year_requirement_satisfied | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_joint_threshold_base | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_maximum_before_phaseout | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_modified_adjusted_gross_income | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_phaseout_amount | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_phaseout_increment | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_phaseout_reduction_per_increment | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_phaseout_threshold | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_phaseout_threshold_base | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_prior_claim_restriction_satisfied | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_qualifying_children_count | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_reckless_disallowance_years | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_separate_threshold_base | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_taxpayer_identification_requirement_satisfied | pass |  |
| post_2017_joint_credit_composes_subsection_h_and_phaseout | q_ctc_unmarried_threshold_base | pass |  |
| taxpayer_tin_after_due_date_disallows_credit | q_ctc_after_advance_payments | pass |  |
| taxpayer_tin_after_due_date_disallows_credit | q_ctc_before_advance_payments | pass |  |
| taxpayer_tin_after_due_date_disallows_credit | q_ctc_taxpayer_identification_requirement_satisfied | pass |  |

