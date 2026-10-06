# Migration ledger: us_statutes_7_2015_d_2_c

Source: Axiom RuleSpec — sources/us/statutes/7/2015/e.yaml, sources/us/statutes/7/2015/d/2/C.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-06
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 43 |
| approximated | 0 |
| residue | 0 |
| **total** | 43 |

Fidelity: **8 of 8** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2015/e#student_under_age_exception_threshold_years | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_student_under_age_exception_threshold_years |  |
| us:statutes/7/2015/e#student_older_age_exception_threshold_years | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_student_older_age_exception_threshold_years |  |
| us:statutes/7/2015/e#snap_employment_and_training_career_technical_program_max_years | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_employment_and_training_career_technical_program_max_years |  |
| us:statutes/7/2015/e#student_minimum_employment_hours_per_week | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_student_minimum_employment_hours_per_week |  |
| us:statutes/7/2015/e#student_parent_young_child_age_threshold_years | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_student_parent_young_child_age_threshold_years |  |
| us:statutes/7/2015/e#student_parent_older_child_lower_age_threshold_years | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_student_parent_older_child_lower_age_threshold_years |  |
| us:statutes/7/2015/e#student_parent_older_child_upper_age_threshold_years | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_student_parent_older_child_upper_age_threshold_years |  |
| us:statutes/7/2015/e#student_single_parent_child_age_threshold_years | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_student_single_parent_child_age_threshold_years |  |
| us:statutes/7/2015/e#student_age_exception_applies | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_student_age_exception_applies |  |
| us:statutes/7/2015/e#snap_employment_and_training_course_condition_applies | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_snap_employment_and_training_course_condition_applies |  |
| us:statutes/7/2015/e#student_assignment_or_placement_exception_applies | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_student_assignment_or_placement_exception_applies |  |
| us:statutes/7/2015/e#student_work_exception_applies | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_student_work_exception_applies |  |
| us:statutes/7/2015/e#student_parent_child_care_exception_applies | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_student_parent_child_care_exception_applies |  |
| us:statutes/7/2015/e#student_single_parent_exception_applies | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_student_single_parent_exception_applies |  |
| us:statutes/7/2015/e#student_exception_applies | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_student_exception_applies |  |
| us:statutes/7/2015/e#student_ineligible_for_snap_participation | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_student_ineligible_for_snap_participation |  |
| us:statutes/7/2015/d/2/C#bona_fide_student_half_time_enrollment_exemption_applies | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_bona_fide_student_half_time_enrollment_exemption_applies |  |
| us:statutes/7/2015/d/2/C#higher_education_student_ineligible_for_snap_participation | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_higher_education_student_ineligible_for_snap_participation |  |
| input person_age_years | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_age_years |  |
| input program_of_study_is_part_of_career_and_technical_education | input | encoded | a name no rule defines -> a fact the scenario states | rs_program_of_study_is_part_of_career_and_technical_education |  |
| input program_of_study_may_be_completed_in_years | input | encoded | a name no rule defines -> a fact the scenario states | rs_program_of_study_may_be_completed_in_years |  |
| input program_of_study_is_at_institution_of_higher_education | input | encoded | a name no rule defines -> a fact the scenario states | rs_program_of_study_is_at_institution_of_higher_education |  |
| input program_of_study_limited_to_remedial_courses_basic_adult_education_literacy_or_english_as_second_language | input | encoded | a name no rule defines -> a fact the scenario states | rs_program_of_study_limited_to_remedial_courses_basic_adult_education_literacy_or_english_as_second_language |  |
| input person_assigned_to_or_placed_in_ihe_through_or_in_compliance_with_wioa_title_i_program | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_assigned_to_or_placed_in_ihe_through_or_in_compliance_with_wioa_title_i_program |  |
| input person_assigned_to_or_placed_in_ihe_through_or_in_compliance_with_snap_employment_and_training_program | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_assigned_to_or_placed_in_ihe_through_or_in_compliance_with_snap_employment_and_training_program |  |
| input person_assigned_to_or_placed_in_ihe_through_or_in_compliance_with_trade_adjustment_assistance_program_under_19_usc_2296 | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_assigned_to_or_placed_in_ihe_through_or_in_compliance_with_trade_adjustment_assistance_program_under_19_usc_2296 |  |
| input person_assigned_to_or_placed_in_ihe_through_or_in_compliance_with_other_state_or_local_government_employment_and_training_program | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_assigned_to_or_placed_in_ihe_through_or_in_compliance_with_other_state_or_local_government_employment_and_training_program |  |
| input secretary_determined_other_state_or_local_government_employment_and_training_program_appropriate | input | encoded | a name no rule defines -> a fact the scenario states | rs_secretary_determined_other_state_or_local_government_employment_and_training_program_appropriate |  |
| input employed_hours_per_week | input | encoded | a name no rule defines -> a fact the scenario states | rs_employed_hours_per_week |  |
| input person_participates_in_state_or_federally_financed_work_study_program_during_regular_school_year | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_participates_in_state_or_federally_financed_work_study_program_during_regular_school_year |  |
| input person_is_parent_with_responsibility_for_care_of_dependent_child | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_parent_with_responsibility_for_care_of_dependent_child |  |
| input dependent_child_age_years | input | encoded | a name no rule defines -> a fact the scenario states | rs_dependent_child_age_years |  |
| input adequate_child_care_not_available_to_enable_individual_to_attend_class_and_satisfy_paragraph_4 | input | encoded | a name no rule defines -> a fact the scenario states | rs_adequate_child_care_not_available_to_enable_individual_to_attend_class_and_satisfy_paragraph_4 |  |
| input person_is_enrolled_full_time_in_institution_of_higher_education_as_determined_by_institution | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_enrolled_full_time_in_institution_of_higher_education_as_determined_by_institution |  |
| input person_is_single_parent_with_responsibility_for_care_of_dependent_child | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_single_parent_with_responsibility_for_care_of_dependent_child |  |
| input person_is_not_physically_or_mentally_fit | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_not_physically_or_mentally_fit |  |
| input person_receiving_benefits_under_state_program_funded_under_part_a_title_iv_social_security_act | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_receiving_benefits_under_state_program_funded_under_part_a_title_iv_social_security_act |  |
| input person_enrolled_as_result_of_participation_in_work_incentive_program_under_title_iv_social_security_act_or_successor | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_enrolled_as_result_of_participation_in_work_incentive_program_under_title_iv_social_security_act_or_successor |  |
| input person_is_member_of_household_otherwise_eligible_to_participate_under_this_section | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_member_of_household_otherwise_eligible_to_participate_under_this_section |  |
| input person_is_enrolled_at_least_half_time_in_institution_of_higher_education | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_enrolled_at_least_half_time_in_institution_of_higher_education |  |
| input person_otherwise_required_to_comply_with_paragraph_1_requirements | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_otherwise_required_to_comply_with_paragraph_1_requirements |  |
| input person_is_bona_fide_student_enrolled_at_least_half_time_in_recognized_school_or_training_program | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_bona_fide_student_enrolled_at_least_half_time_in_recognized_school_or_training_program |  |
| input person_is_bona_fide_student_enrolled_at_least_half_time_in_institution_of_higher_education | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_bona_fide_student_enrolled_at_least_half_time_in_institution_of_higher_education |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| recognized_school_or_training_student_is_exempt | q_bona_fide_student_half_time_enrollment_exemption_applies | pass |  |
| recognized_school_or_training_student_is_exempt | q_higher_education_student_ineligible_for_snap_participation | pass |  |
| higher_education_student_with_no_subsection_e_exception_is_ineligible | q_bona_fide_student_half_time_enrollment_exemption_applies | pass |  |
| higher_education_student_with_no_subsection_e_exception_is_ineligible | q_higher_education_student_ineligible_for_snap_participation | pass |  |
| higher_education_student_meeting_subsection_e_exception_is_not_ineligible_under_exception_clause | q_bona_fide_student_half_time_enrollment_exemption_applies | pass |  |
| higher_education_student_meeting_subsection_e_exception_is_not_ineligible_under_exception_clause | q_higher_education_student_ineligible_for_snap_participation | pass |  |
| no_bona_fide_half_time_student_status_no_branch_exemption | q_bona_fide_student_half_time_enrollment_exemption_applies | pass |  |
| no_bona_fide_half_time_student_status_no_branch_exemption | q_higher_education_student_ineligible_for_snap_participation | pass |  |

