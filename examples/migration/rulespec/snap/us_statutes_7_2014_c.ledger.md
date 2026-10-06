# Migration ledger: us_statutes_7_2014_c

Source: Axiom RuleSpec — sources/us/statutes/7/2014/e/2/B.yaml, sources/us/statutes/7/2014/e/2.yaml, sources/us/statutes/7/2014/e/6/A.yaml, sources/us/statutes/7/2014/c.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-06
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 23 |
| approximated | 0 |
| residue | 0 |
| **total** | 23 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

**13 further expectation(s) are pending** (the engine does not reproduce this case of the test file (fail)): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2014/e/2/B#snap_earned_income_deduction_rate | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_earned_income_deduction_rate |  |
| us:statutes/7/2014/e/2#snap_earned_income_subject_to_deduction | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_earned_income_subject_to_deduction |  |
| us:statutes/7/2014/e/2#snap_earned_income_deduction | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_earned_income_deduction |  |
| us:statutes/7/2014/e/6/A#snap_net_income_pre_shelter | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_net_income_pre_shelter |  |
| us:statutes/7/2014/e/6/A#snap_net_income | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_net_income |  |
| us:statutes/7/2014/c#snap_gross_income_excess_rate_over_poverty_line | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_gross_income_excess_rate_over_poverty_line |  |
| us:statutes/7/2014/c#snap_income_standard_poverty_line_with_territory_cap | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_income_standard_poverty_line_with_territory_cap |  |
| us:statutes/7/2014/c#snap_net_income_exceeds_poverty_line | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_snap_net_income_exceeds_poverty_line |  |
| us:statutes/7/2014/c#household_fails_gross_income_standard | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_household_fails_gross_income_standard |  |
| us:statutes/7/2014/c#household_ineligible_to_participate_due_to_income_standards | derived | encoded | derived judgment -> a rule concluding a sentence, 1 version(s) guarded by the calculation date | rs_household_ineligible_to_participate_due_to_income_standards |  |
| input snap_countable_earned_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_countable_earned_income |  |
| input work_supplementation_earned_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_work_supplementation_earned_income |  |
| input snap_monthly_household_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_monthly_household_income |  |
| input snap_standard_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_standard_deduction |  |
| input dependent_care_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_dependent_care_deduction |  |
| input child_support_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_child_support_deduction |  |
| input medical_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_medical_deduction |  |
| input snap_excess_shelter_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_excess_shelter_deduction |  |
| input household_is_in_virgin_islands_or_guam | input | encoded | a name no rule defines -> a fact the scenario states | rs_household_is_in_virgin_islands_or_guam |  |
| input poverty_line_under_42_usc_9902_2_for_household_area | input | encoded | a name no rule defines -> a fact the scenario states | rs_poverty_line_under_42_usc_9902_2_for_household_area |  |
| input poverty_line_under_42_usc_9902_2_for_forty_eight_contiguous_states_and_dc | input | encoded | a name no rule defines -> a fact the scenario states | rs_poverty_line_under_42_usc_9902_2_for_forty_eight_contiguous_states_and_dc |  |
| input household_includes_elderly_or_disabled_member | input | encoded | a name no rule defines -> a fact the scenario states | rs_household_includes_elderly_or_disabled_member |  |
| input snap_total_gross_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_total_gross_income |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| elderly_or_disabled_member_removes_gross_income_standard_failure | q_household_fails_gross_income_standard | pass |  |
| elderly_or_disabled_member_removes_gross_income_standard_failure | q_household_ineligible_to_participate_due_to_income_standards | pass |  |
| elderly_or_disabled_member_removes_gross_income_standard_failure | q_snap_income_standard_poverty_line_with_territory_cap | pass |  |
| elderly_or_disabled_member_removes_gross_income_standard_failure | q_snap_net_income_exceeds_poverty_line | pass |  |

