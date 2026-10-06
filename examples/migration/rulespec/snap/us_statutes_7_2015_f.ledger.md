# Migration ledger: us_statutes_7_2015_f

Source: Axiom RuleSpec — sources/us/statutes/7/2015/f.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-06
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 16 |
| approximated | 0 |
| residue | 0 |
| **total** | 16 |

Fidelity: **35 of 35** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2015/f#qualifying_immigration_or_nationality_status_for_snap_participation | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_qualifying_immigration_or_nationality_status_for_snap_participation |  |
| us:statutes/7/2015/f#citizenship_or_nationality_qualifies_for_snap_participation | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_citizenship_or_nationality_qualifies_for_snap_participation |  |
| us:statutes/7/2015/f#individual_ineligible_for_snap_participation_due_to_residence_or_status | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_individual_ineligible_for_snap_participation_due_to_residence_or_status |  |
| us:statutes/7/2015/f#individual_income_considered_for_household_eligibility_and_allotment | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_individual_income_considered_for_household_eligibility_and_allotment |  |
| us:statutes/7/2015/f#individual_financial_resources_considered_for_household_eligibility_and_allotment | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_individual_financial_resources_considered_for_household_eligibility_and_allotment |  |
| input person_is_alien_lawfully_admitted_for_permanent_residence_as_immigrant | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_alien_lawfully_admitted_for_permanent_residence_as_immigrant |  |
| input person_has_been_granted_status_of_cuban_and_haitian_entrant | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_has_been_granted_status_of_cuban_and_haitian_entrant |  |
| input person_lawfully_resides_in_united_states_in_accordance_with_compact_of_free_association | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_lawfully_resides_in_united_states_in_accordance_with_compact_of_free_association |  |
| input person_is_citizen_of_united_states | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_citizen_of_united_states |  |
| input person_is_national_of_united_states | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_national_of_united_states |  |
| input person_is_member_of_household_otherwise_eligible_to_participate_under_this_section | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_member_of_household_otherwise_eligible_to_participate_under_this_section |  |
| input person_is_resident_of_united_states | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_resident_of_united_states |  |
| input individual_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_income |  |
| input state_exercises_income_pro_rata_share_option | input | encoded | a name no rule defines -> a fact the scenario states | rs_state_exercises_income_pro_rata_share_option |  |
| input income_pro_rata_share | input | encoded | a name no rule defines -> a fact the scenario states | rs_income_pro_rata_share |  |
| input individual_financial_resources | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_financial_resources |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| negative_resources_are_clamped_at_zero | q_citizenship_or_nationality_qualifies_for_snap_participation | pass |  |
| negative_resources_are_clamped_at_zero | q_individual_financial_resources_considered_for_household_eligibility_and_allotment | pass |  |
| negative_resources_are_clamped_at_zero | q_individual_ineligible_for_snap_participation_due_to_residence_or_status | pass |  |
| negative_resources_are_clamped_at_zero | q_qualifying_immigration_or_nationality_status_for_snap_participation | pass |  |
| citizen_resident_member_has_qualifying_status | q_citizenship_or_nationality_qualifies_for_snap_participation | pass |  |
| citizen_resident_member_has_qualifying_status | q_individual_ineligible_for_snap_participation_due_to_residence_or_status | pass |  |
| citizen_resident_member_has_qualifying_status | q_qualifying_immigration_or_nationality_status_for_snap_participation | pass |  |
| national_only_resident_member_has_qualifying_status | q_citizenship_or_nationality_qualifies_for_snap_participation | pass |  |
| national_only_resident_member_has_qualifying_status | q_individual_ineligible_for_snap_participation_due_to_residence_or_status | pass |  |
| national_only_resident_member_has_qualifying_status | q_qualifying_immigration_or_nationality_status_for_snap_participation | pass |  |
| lawful_permanent_resident_has_qualifying_status | q_citizenship_or_nationality_qualifies_for_snap_participation | pass |  |
| lawful_permanent_resident_has_qualifying_status | q_individual_ineligible_for_snap_participation_due_to_residence_or_status | pass |  |
| lawful_permanent_resident_has_qualifying_status | q_qualifying_immigration_or_nationality_status_for_snap_participation | pass |  |
| cuban_haitian_entrant_has_qualifying_status | q_individual_ineligible_for_snap_participation_due_to_residence_or_status | pass |  |
| cuban_haitian_entrant_has_qualifying_status | q_qualifying_immigration_or_nationality_status_for_snap_participation | pass |  |
| compact_of_free_association_resident_has_qualifying_status | q_individual_ineligible_for_snap_participation_due_to_residence_or_status | pass |  |
| compact_of_free_association_resident_has_qualifying_status | q_qualifying_immigration_or_nationality_status_for_snap_participation | pass |  |
| member_with_no_permitted_status_is_ineligible | q_citizenship_or_nationality_qualifies_for_snap_participation | pass |  |
| member_with_no_permitted_status_is_ineligible | q_individual_ineligible_for_snap_participation_due_to_residence_or_status | pass |  |
| member_with_no_permitted_status_is_ineligible | q_qualifying_immigration_or_nationality_status_for_snap_participation | pass |  |
| nonresident_member_is_ineligible | q_individual_ineligible_for_snap_participation_due_to_residence_or_status | pass |  |
| nonresident_member_is_ineligible | q_qualifying_immigration_or_nationality_status_for_snap_participation | pass |  |
| nonmember_is_not_ineligible_under_this_subsection | q_individual_ineligible_for_snap_participation_due_to_residence_or_status | pass |  |
| nonmember_is_not_ineligible_under_this_subsection | q_qualifying_immigration_or_nationality_status_for_snap_participation | pass |  |
| ineligible_income_without_proration_is_considered | q_individual_income_considered_for_household_eligibility_and_allotment | pass |  |
| ineligible_income_without_proration_is_considered | q_individual_ineligible_for_snap_participation_due_to_residence_or_status | pass |  |
| ineligible_income_with_proration_is_considered | q_individual_income_considered_for_household_eligibility_and_allotment | pass |  |
| ineligible_income_with_proration_is_considered | q_individual_ineligible_for_snap_participation_due_to_residence_or_status | pass |  |
| income_proration_is_clamped_at_zero | q_individual_income_considered_for_household_eligibility_and_allotment | pass |  |
| income_proration_is_clamped_at_zero | q_individual_ineligible_for_snap_participation_due_to_residence_or_status | pass |  |
| ineligible_positive_resources_are_considered | q_individual_financial_resources_considered_for_household_eligibility_and_allotment | pass |  |
| ineligible_positive_resources_are_considered | q_individual_ineligible_for_snap_participation_due_to_residence_or_status | pass |  |
| eligible_person_income_and_resources_are_not_considered | q_individual_financial_resources_considered_for_household_eligibility_and_allotment | pass |  |
| eligible_person_income_and_resources_are_not_considered | q_individual_income_considered_for_household_eligibility_and_allotment | pass |  |
| eligible_person_income_and_resources_are_not_considered | q_individual_ineligible_for_snap_participation_due_to_residence_or_status | pass |  |

