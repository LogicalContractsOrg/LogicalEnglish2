# Migration ledger: us_statutes_7_2014_d

Source: Axiom RuleSpec — sources/us/statutes/7/2014/d.yaml
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

Fidelity: **8 of 8** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2014/d#irregular_income_quarter_cap | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_irregular_income_quarter_cap |  |
| us:statutes/7/2014/d#irregular_income_excluded_from_snap_income | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_irregular_income_excluded_from_snap_income |  |
| us:statutes/7/2014/d#student_child_income_age_limit | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_student_child_income_age_limit |  |
| us:statutes/7/2014/d#student_child_earned_income_excluded_from_snap_income | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_student_child_earned_income_excluded_from_snap_income |  |
| input income_received_too_infrequently_or_irregularly_to_be_reasonably_anticipated | input | encoded | a name no rule defines -> a fact the scenario states | rs_income_received_too_infrequently_or_irregularly_to_be_reasonably_anticipated |  |
| input irregular_income_amount_in_certification_period | input | encoded | a name no rule defines -> a fact the scenario states | rs_irregular_income_amount_in_certification_period |  |
| input person_is_child_member_of_household | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_child_member_of_household |  |
| input person_is_elementary_or_secondary_school_student | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_is_elementary_or_secondary_school_student |  |
| input person_age | input | encoded | a name no rule defines -> a fact the scenario states | rs_person_age |  |
| input child_earned_income_amount | input | encoded | a name no rule defines -> a fact the scenario states | rs_child_earned_income_amount |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| irregular_income_exclusion_caps_at_quarter_limit | q_irregular_income_excluded_from_snap_income | pass |  |
| irregular_income_exclusion_caps_at_quarter_limit | q_irregular_income_quarter_cap | pass |  |
| irregular_income_not_excluded_without_irregularity_condition | q_irregular_income_excluded_from_snap_income | pass |  |
| student_child_earned_income_excluded_at_age_limit | q_student_child_earned_income_excluded_from_snap_income | pass |  |
| student_child_earned_income_excluded_at_age_limit | q_student_child_income_age_limit | pass |  |
| student_child_earned_income_not_excluded_over_age_limit | q_student_child_earned_income_excluded_from_snap_income | pass |  |
| student_income_not_excluded_if_not_household_child | q_student_child_earned_income_excluded_from_snap_income | pass |  |
| student_income_not_excluded_if_not_student | q_student_child_earned_income_excluded_from_snap_income | pass |  |

