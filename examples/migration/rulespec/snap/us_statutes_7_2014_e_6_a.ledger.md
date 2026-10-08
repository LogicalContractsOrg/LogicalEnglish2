# Migration ledger: us_statutes_7_2014_e_6_a

Source: Axiom RuleSpec — sources/us/statutes/7/2014/e/2/B.yaml, sources/us/statutes/7/2014/e/2.yaml, sources/us/statutes/7/2014/e/6/A.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-07
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 13 |
| approximated | 0 |
| residue | 0 |
| **total** | 13 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/7/2014/e/2/B#snap_earned_income_deduction_rate | parameter | encoded | parameter -> a fact, cited, 1 version(s) guarded by the calculation date | rs_snap_earned_income_deduction_rate |  |
| us:statutes/7/2014/e/2#snap_earned_income_subject_to_deduction | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_earned_income_subject_to_deduction |  |
| us:statutes/7/2014/e/2#snap_earned_income_deduction | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_earned_income_deduction |  |
| us:statutes/7/2014/e/6/A#snap_net_income_pre_shelter | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_net_income_pre_shelter |  |
| us:statutes/7/2014/e/6/A#snap_net_income | derived | encoded | derived value -> a rule, the formula's names as conditions, 1 version(s) guarded by the calculation date | rs_snap_net_income |  |
| input snap_countable_earned_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_countable_earned_income |  |
| input work_supplementation_earned_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_work_supplementation_earned_income |  |
| input snap_monthly_household_income | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_monthly_household_income |  |
| input snap_standard_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_standard_deduction |  |
| input dependent_care_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_dependent_care_deduction |  |
| input child_support_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_child_support_deduction |  |
| input medical_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_medical_deduction |  |
| input snap_excess_shelter_deduction | input | encoded | a name no rule defines -> a fact the scenario states | rs_snap_excess_shelter_deduction |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| pre_shelter_net_income_subtracts_applicable_non_shelter_deductions | q_snap_net_income | pass |  |
| pre_shelter_net_income_subtracts_applicable_non_shelter_deductions | q_snap_net_income_pre_shelter | pass |  |
| deductions_cannot_reduce_snap_net_income_below_zero | q_snap_net_income | pass |  |
| deductions_cannot_reduce_snap_net_income_below_zero | q_snap_net_income_pre_shelter | pass |  |

