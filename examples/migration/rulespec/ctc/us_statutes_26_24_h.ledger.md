# Migration ledger: us_statutes_26_24_h

Source: Axiom RuleSpec — sources/us/statutes/26/24/h.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-07
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
| input taxpayer_or_spouse_ssn_included_on_return | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_or_spouse_ssn_included_on_return |  |
| input qualifying_child_ssn_included_on_return | input | encoded | a name no rule defines -> a fact the scenario states | rs_qualifying_child_ssn_included_on_return |  |
| input taxpayer_or_spouse_ssn_is_valid_for_subsection_h | input | encoded | a name no rule defines -> a fact the scenario states | rs_taxpayer_or_spouse_ssn_is_valid_for_subsection_h |  |
| input qualifying_child_ssn_is_valid_for_subsection_h | input | encoded | a name no rule defines -> a fact the scenario states | rs_qualifying_child_ssn_is_valid_for_subsection_h |  |
| input ctc_child_satisfies_subsection_c | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_child_satisfies_subsection_c |  |
| input ctc_person_satisfies_dependency_rules | input | encoded | a name no rule defines -> a fact the scenario states | rs_ctc_person_satisfies_dependency_rules |  |
| input noncitizen_exception_to_other_dependent_credit_under_subsection_h | input | encoded | a name no rule defines -> a fact the scenario states | rs_noncitizen_exception_to_other_dependent_credit_under_subsection_h |  |
| input filing_status | input | encoded | a name no rule defines -> a fact the scenario states | rs_filing_status |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| other_dependent_positive_path | q_ctc_child_credit_disallowed_by_ssn_requirement_under_subsection_h | pass |  |
| other_dependent_positive_path | q_ctc_child_ssn_requirement_satisfied_under_subsection_h | pass |  |
| other_dependent_positive_path | q_ctc_other_dependent_under_subsection_h | pass |  |
| other_dependent_positive_path | q_ctc_qualifying_child_under_subsection_h | pass |  |
| other_dependent_noncitizen_exception_path | q_ctc_other_dependent_under_subsection_h | pass |  |
| qualifying_child_with_required_social_security_numbers | q_ctc_child_credit_disallowed_by_ssn_requirement_under_subsection_h | pass |  |
| qualifying_child_with_required_social_security_numbers | q_ctc_child_ssn_requirement_satisfied_under_subsection_h | pass |  |
| qualifying_child_with_required_social_security_numbers | q_ctc_other_dependent_under_subsection_h | pass |  |
| qualifying_child_with_required_social_security_numbers | q_ctc_qualifying_child_under_subsection_h | pass |  |
| joint_return_aggregate_credit_and_refundable_cap | q_ctc_child_amount_under_subsection_h | pass |  |
| joint_return_aggregate_credit_and_refundable_cap | q_ctc_joint_phase_out_threshold_under_subsection_h | pass |  |
| joint_return_aggregate_credit_and_refundable_cap | q_ctc_maximum_before_phase_out_under_subsection_h | pass |  |
| joint_return_aggregate_credit_and_refundable_cap | q_ctc_other_dependent_amount_under_subsection_h | pass |  |
| joint_return_aggregate_credit_and_refundable_cap | q_ctc_other_dependents_under_subsection_h | pass |  |
| joint_return_aggregate_credit_and_refundable_cap | q_ctc_other_phase_out_threshold_under_subsection_h | pass |  |
| joint_return_aggregate_credit_and_refundable_cap | q_ctc_phase_out_threshold_under_subsection_h | pass |  |
| joint_return_aggregate_credit_and_refundable_cap | q_ctc_qualifying_children_under_subsection_h | pass |  |
| joint_return_aggregate_credit_and_refundable_cap | q_ctc_refundable_maximum_under_subsection_h | pass |  |
| joint_return_aggregate_credit_and_refundable_cap | q_ctc_refundable_per_child_cap_under_subsection_h | pass |  |
| joint_return_aggregate_credit_and_refundable_cap | q_ctc_refundable_phase_in_threshold_under_subsection_h | pass |  |

