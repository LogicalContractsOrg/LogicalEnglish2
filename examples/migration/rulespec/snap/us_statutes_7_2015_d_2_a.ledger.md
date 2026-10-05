# Migration ledger: us_statutes_7_2015_d_2_a

Source: Axiom RuleSpec — sources/us/statutes/7/2015/d/2/A.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-05
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 10 |
| approximated | 0 |
| residue | 0 |
| **total** | 10 |

Fidelity: **8 of 8** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2015/d/2/A#title_iv_or_unemployment_work_registration_compliance_exemption_applies | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_title_iv_or_unemployment_work_registration_compliance_exemption_applies |  |
| us:statutes/7/2015/d/2/A#title_iv_or_unemployment_work_registration_compliance_exemption_applies | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_title_iv_or_unemployment_work_registration_compliance_exemption_applies |  |
| us:statutes/7/2015/d/2/A#subject_work_requirement_noncompliance_treated_as_paragraph_1_failure | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_subject_work_requirement_noncompliance_treated_as_paragraph_1_failure |  |
| us:statutes/7/2015/d/2/A#subject_work_requirement_noncompliance_treated_as_paragraph_1_failure | derived | encoded | rule, 1 version(s) guarded by the calculation date | rs_subject_work_requirement_noncompliance_treated_as_paragraph_1_failure |  |
| input person_otherwise_required_to_comply_with_paragraph_1_requirements | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_otherwise_required_to_comply_with_paragraph_1_requirements |  |
| input currently_subject_to_title_iv_work_registration_requirement | input | encoded | a name no rule defines -> a fact the scenario states | rs_currently_subject_to_title_iv_work_registration_requirement |  |
| input complying_with_title_iv_work_registration_requirement | input | encoded | a name no rule defines -> a fact the scenario states | rs_complying_with_title_iv_work_registration_requirement |  |
| input currently_subject_to_federal_state_unemployment_compensation_work_registration_requirement | input | encoded | a name no rule defines -> a fact the scenario states | rs_currently_subject_to_federal_state_unemployment_compensation_work_registration_requirement |  |
| input complying_with_federal_state_unemployment_compensation_work_registration_requirement | input | encoded | a name no rule defines -> a fact the scenario states | rs_complying_with_federal_state_unemployment_compensation_work_registration_requirement |  |
| input person_fails_to_comply_with_any_work_requirement_to_which_person_is_subject | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_fails_to_comply_with_any_work_requirement_to_which_person_is_subject |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| title_iv_work_registration_compliance_exemption_applies | q_subject_work_requirement_noncompliance_treated_as_paragraph_1_failure | pass |  |
| title_iv_work_registration_compliance_exemption_applies | q_title_iv_or_unemployment_work_registration_compliance_exemption_applies | pass |  |
| unemployment_compensation_work_registration_compliance_exemption_applies | q_subject_work_requirement_noncompliance_treated_as_paragraph_1_failure | pass |  |
| unemployment_compensation_work_registration_compliance_exemption_applies | q_title_iv_or_unemployment_work_registration_compliance_exemption_applies | pass |  |
| noncompliance_with_subject_work_requirement_counts_as_paragraph_1_failure | q_subject_work_requirement_noncompliance_treated_as_paragraph_1_failure | pass |  |
| noncompliance_with_subject_work_requirement_counts_as_paragraph_1_failure | q_title_iv_or_unemployment_work_registration_compliance_exemption_applies | pass |  |
| person_not_otherwise_required_has_no_branch_exemption_or_failure_treatment | q_subject_work_requirement_noncompliance_treated_as_paragraph_1_failure | pass |  |
| person_not_otherwise_required_has_no_branch_exemption_or_failure_treatment | q_title_iv_or_unemployment_work_registration_compliance_exemption_applies | pass |  |

