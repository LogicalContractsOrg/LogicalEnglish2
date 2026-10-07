# Migration ledger: us_statutes_42_1382b_a

Source: Axiom RuleSpec — sources/us/statutes/42/1382b/a.yaml
Translator: lpsPlus migration/rulespec
Date: 2026-10-07
Source licence: CC-BY-4.0 (rulespec-us, Axiom Foundation)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 16 |
| approximated | 0 |
| residue | 0 |
| **total** | 16 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| us:statutes/42/1382b/a#alaska_native_stock_inalienability_exclusion_period_years | parameter | encoded | parameter -> a fact, cited | rs_alaska_native_stock_inalienability_exclusion_period_years |  |
| us:statutes/42/1382b/a#assistance_resource_exclusion_period_months | parameter | encoded | parameter -> a fact, cited | rs_assistance_resource_exclusion_period_months |  |
| us:statutes/42/1382b/a#prior_underpayment_resource_exclusion_period_months | parameter | encoded | parameter -> a fact, cited | rs_prior_underpayment_resource_exclusion_period_months |  |
| us:statutes/42/1382b/a#post_receipt_resource_exclusion_period_months | parameter | encoded | parameter -> a fact, cited | rs_post_receipt_resource_exclusion_period_months |  |
| us:statutes/42/1382b/a#qualifying_gift_child_age_ceiling_years | parameter | encoded | parameter -> a fact, cited | rs_qualifying_gift_child_age_ceiling_years |  |
| us:statutes/42/1382b/a#annual_cash_gift_resource_exclusion_cap | parameter | encoded | parameter -> a fact, cited | rs_annual_cash_gift_resource_exclusion_cap |  |
| us:statutes/42/1382b/a#life_insurance_face_value_disregard_threshold | parameter | encoded | parameter -> a fact, cited | rs_life_insurance_face_value_disregard_threshold |  |
| us:statutes/42/1382b/a#life_insurance_policy_counted_resource_value | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_life_insurance_policy_counted_resource_value |  |
| us:statutes/42/1382b/a#qualifying_cash_gift_excluded_resource_amount | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_qualifying_cash_gift_excluded_resource_amount |  |
| input total_face_value_of_all_life_insurance_policies_on_same_person | input | encoded | a name no rule defines -> a fact the scenario states | rs_total_face_value_of_all_life_insurance_policies_on_same_person |  |
| input cash_surrender_value | input | encoded | a name no rule defines -> a fact the scenario states | rs_cash_surrender_value |  |
| input individual_age_years | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_age_years |  |
| input individual_has_life_threatening_condition | input | encoded | a name no rule defines -> a fact the scenario states | rs_individual_has_life_threatening_condition |  |
| input gift_from_organization_described_in_section_501_c_3_exempt_under_section_501_a | input | encoded | a name no rule defines -> a fact the scenario states | rs_gift_from_organization_described_in_section_501_c_3_exempt_under_section_501_a |  |
| input gift_is_cash | input | encoded | a name no rule defines -> a fact the scenario states | rs_gift_is_cash |  |
| input cash_gift_amount | input | encoded | a name no rule defines -> a fact the scenario states | rs_cash_gift_amount |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| life_insurance_policy_disregarded_when_total_face_value_at_threshold | q_life_insurance_policy_counted_resource_value | pass |  |
| life_insurance_policy_counted_at_cash_surrender_value_when_total_face_value_exceeds_threshold | q_life_insurance_policy_counted_resource_value | pass |  |
| qualifying_cash_gift_excluded_up_to_annual_cap | q_qualifying_cash_gift_excluded_resource_amount | pass |  |
| cash_gift_not_excluded_when_child_age_condition_fails | q_qualifying_cash_gift_excluded_resource_amount | pass |  |

