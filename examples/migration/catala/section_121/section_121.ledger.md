# Migration ledger: cat_section_121

Source: Catala (catala-examples) — sources/cat/section_121.yaml
Translator: lpsPlus migration/catala
Date: 2026-10-07
Source licence: Apache-2.0 (catala-examples, Inria and contributors)

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 48 |
| approximated | 0 |
| residue | 15 |
| **total** | 63 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

**2 further expectation(s) are pending** (waits for residue r10, r14): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| cat:section_121#is_in_section121_single_person_property_ownage | input | encoded | input -> a fact the scenario states | rs_is_in_section121_single_person_property_ownage |  |
| cat:section_121#is_in_section121_single_person_property_usage_as_principal_residence | input | encoded | input -> a fact the scenario states | rs_is_in_section121_single_person_property_usage_as_principal_residence |  |
| cat:section_121#section121_single_person_begin | input | encoded | input -> a fact the scenario states | rs_section121_single_person_begin |  |
| cat:section_121#section121_single_person_date_of_sale_or_exchange | input | encoded | input -> a fact the scenario states | rs_section121_single_person_date_of_sale_or_exchange |  |
| cat:section_121#section121_single_person_end | input | encoded | input -> a fact the scenario states | rs_section121_single_person_end |  |
| cat:section_121#section121_single_person_gain_cap | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_single_person_gain_cap |  |
| cat:section_121#section121_single_person_gain_from_sale_or_exchange_of_property | input | encoded | input -> a fact the scenario states | rs_section121_single_person_gain_from_sale_or_exchange_of_property |  |
| cat:section_121#section121_single_person_income_excluded_from_gross_income | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_single_person_income_excluded_from_gross_income |  |
| cat:section_121#section121_single_person_income_excluded_from_gross_income_uncapped | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_single_person_income_excluded_from_gross_income_uncapped |  |
| cat:section_121#section121_single_person_other_section_121a_sale | input | encoded | input -> a fact the scenario states | rs_section121_single_person_other_section_121a_sale |  |
| cat:section_121#section121_single_person_requirements_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_single_person_requirements_met |  |
| cat:section_121#section121_single_person_requirements_ownership_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_single_person_requirements_ownership_met |  |
| cat:section_121#section121_single_person_requirements_usage_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_single_person_requirements_usage_met |  |
| cat:section_121#section121_single_person_section_121_b_3_applies | derived | residue | residue block r1 with the rule's YAML | rs_section121_single_person_section_121_b_3_applies |  |
| cat:section_121#section121_two_persons_date_of_sale_or_exchange | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_gain_cap | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_gain_cap |  |
| cat:section_121#section121_two_persons_gain_cap_person_1 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_gain_cap_person_1 |  |
| cat:section_121#section121_two_persons_gain_cap_person_2 | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_gain_cap_person_2 |  |
| cat:section_121#section121_two_persons_gain_from_sale_or_exchange_of_property | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_gain_from_sale_or_exchange_of_property |  |
| cat:section_121#section121_two_persons_income_excluded_from_gross_income | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_income_excluded_from_gross_income |  |
| cat:section_121#section121_two_persons_income_excluded_from_gross_income_uncapped | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_income_excluded_from_gross_income_uncapped |  |
| cat:section_121#section121_two_persons_period_merge_output_periods | derived | residue | residue block r2 with the rule's YAML | rs_section121_two_persons_period_merge_output_periods |  |
| cat:section_121#section121_two_persons_period_merge_periods1 | derived | residue | residue block r3 with the rule's YAML | rs_section121_two_persons_period_merge_periods1 |  |
| cat:section_121#section121_two_persons_period_merge_periods2 | derived | residue | residue block r4 with the rule's YAML | rs_section121_two_persons_period_merge_periods2 |  |
| cat:section_121#section121_two_persons_person1 | derived | residue | residue block r5 with the rule's YAML | rs_section121_two_persons_person1 |  |
| cat:section_121#section121_two_persons_person2 | derived | residue | residue block r6 with the rule's YAML | rs_section121_two_persons_person2 |  |
| cat:section_121#section121_two_persons_return_date | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_date |  |
| cat:section_121#section121_two_persons_return_type | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_return_type |  |
| cat:section_121#section121_two_persons_section121Person1_begin | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_section121Person1_begin |  |
| cat:section_121#section121_two_persons_section121Person1_date_of_sale_or_exchange | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person1_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_section121Person1_end | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_section121Person1_end |  |
| cat:section_121#section121_two_persons_section121Person1_gain_cap | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person1_gain_cap |  |
| cat:section_121#section121_two_persons_section121Person1_gain_from_sale_or_exchange_of_property | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person1_gain_from_sale_or_exchange_of_property |  |
| cat:section_121#section121_two_persons_section121Person1_income_excluded_from_gross_income | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person1_income_excluded_from_gross_income |  |
| cat:section_121#section121_two_persons_section121Person1_income_excluded_from_gross_income_uncapped | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person1_income_excluded_from_gross_income_uncapped |  |
| cat:section_121#section121_two_persons_section121Person1_other_section_121a_sale | derived | residue | residue block r7 with the rule's YAML | rs_section121_two_persons_section121Person1_other_section_121a_sale |  |
| cat:section_121#section121_two_persons_section121Person1_property_ownage | derived | residue | residue block r8 with the rule's YAML | rs_section121_two_persons_section121Person1_property_ownage |  |
| cat:section_121#section121_two_persons_section121Person1_property_usage_as_principal_residence | derived | residue | residue block r9 with the rule's YAML | rs_section121_two_persons_section121Person1_property_usage_as_principal_residence |  |
| cat:section_121#section121_two_persons_section121Person1_requirements_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121Person1_requirements_met |  |
| cat:section_121#section121_two_persons_section121Person1_requirements_ownership_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121Person1_requirements_ownership_met |  |
| cat:section_121#section121_two_persons_section121Person1_requirements_usage_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121Person1_requirements_usage_met |  |
| cat:section_121#section121_two_persons_section121Person1_section_121_b_3_applies | derived | residue | residue block r10 with the rule's YAML | rs_section121_two_persons_section121Person1_section_121_b_3_applies |  |
| cat:section_121#section121_two_persons_section121Person2_begin | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_section121Person2_begin |  |
| cat:section_121#section121_two_persons_section121Person2_date_of_sale_or_exchange | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person2_date_of_sale_or_exchange |  |
| cat:section_121#section121_two_persons_section121Person2_end | input | encoded | input -> a fact the scenario states | rs_section121_two_persons_section121Person2_end |  |
| cat:section_121#section121_two_persons_section121Person2_gain_cap | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person2_gain_cap |  |
| cat:section_121#section121_two_persons_section121Person2_gain_from_sale_or_exchange_of_property | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person2_gain_from_sale_or_exchange_of_property |  |
| cat:section_121#section121_two_persons_section121Person2_income_excluded_from_gross_income | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person2_income_excluded_from_gross_income |  |
| cat:section_121#section121_two_persons_section121Person2_income_excluded_from_gross_income_uncapped | derived | encoded | derived value -> a rule, the formula's names as conditions | rs_section121_two_persons_section121Person2_income_excluded_from_gross_income_uncapped |  |
| cat:section_121#section121_two_persons_section121Person2_other_section_121a_sale | derived | residue | residue block r11 with the rule's YAML | rs_section121_two_persons_section121Person2_other_section_121a_sale |  |
| cat:section_121#section121_two_persons_section121Person2_property_ownage | derived | residue | residue block r12 with the rule's YAML | rs_section121_two_persons_section121Person2_property_ownage |  |
| cat:section_121#section121_two_persons_section121Person2_property_usage_as_principal_residence | derived | residue | residue block r13 with the rule's YAML | rs_section121_two_persons_section121Person2_property_usage_as_principal_residence |  |
| cat:section_121#section121_two_persons_section121Person2_requirements_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121Person2_requirements_met |  |
| cat:section_121#section121_two_persons_section121Person2_requirements_ownership_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121Person2_requirements_ownership_met |  |
| cat:section_121#section121_two_persons_section121Person2_requirements_usage_met | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section121Person2_requirements_usage_met |  |
| cat:section_121#section121_two_persons_section121Person2_section_121_b_3_applies | derived | residue | residue block r14 with the rule's YAML | rs_section121_two_persons_section121Person2_section_121_b_3_applies |  |
| cat:section_121#section121_two_persons_section121a_requirements_met | derived | residue | residue block r15 with the rule's YAML | rs_section121_two_persons_section121a_requirements_met |  |
| cat:section_121#section121_two_persons_section_121_b_2_A_condition | derived | encoded | derived judgment -> a rule concluding a sentence | rs_section121_two_persons_section_121_b_2_A_condition |  |
| input Period | input | encoded | a name no rule defines -> a fact the scenario states | rs_Period |  |
| input is_in_section121_two_persons_section121Person1_property_ownage | input | encoded | a name no rule defines -> a fact the scenario states | rs_is_in_section121_two_persons_section121Person1_property_ownage |  |
| input is_in_section121_two_persons_section121Person1_property_usage_as_principal_residence | input | encoded | a name no rule defines -> a fact the scenario states | rs_is_in_section121_two_persons_section121Person1_property_usage_as_principal_residence |  |
| input is_in_section121_two_persons_section121Person2_property_ownage | input | encoded | a name no rule defines -> a fact the scenario states | rs_is_in_section121_two_persons_section121Person2_property_ownage |  |
| input is_in_section121_two_persons_section121Person2_property_usage_as_principal_residence | input | encoded | a name no rule defines -> a fact the scenario states | rs_is_in_section121_two_persons_section121Person2_property_usage_as_principal_residence |  |

## Residue

- **cat:section_121#section121_single_person_section_121_b_3_applies** (derived) — residue block r1 with the rule's YAML; in the program: rs_section121_single_person_section_121_b_3_applies. 
- **cat:section_121#section121_two_persons_period_merge_output_periods** (derived) — residue block r2 with the rule's YAML; in the program: rs_section121_two_persons_period_merge_output_periods. 
- **cat:section_121#section121_two_persons_period_merge_periods1** (derived) — residue block r3 with the rule's YAML; in the program: rs_section121_two_persons_period_merge_periods1. 
- **cat:section_121#section121_two_persons_period_merge_periods2** (derived) — residue block r4 with the rule's YAML; in the program: rs_section121_two_persons_period_merge_periods2. 
- **cat:section_121#section121_two_persons_person1** (derived) — residue block r5 with the rule's YAML; in the program: rs_section121_two_persons_person1. 
- **cat:section_121#section121_two_persons_person2** (derived) — residue block r6 with the rule's YAML; in the program: rs_section121_two_persons_person2. 
- **cat:section_121#section121_two_persons_section121Person1_other_section_121a_sale** (derived) — residue block r7 with the rule's YAML; in the program: rs_section121_two_persons_section121Person1_other_section_121a_sale. 
- **cat:section_121#section121_two_persons_section121Person1_property_ownage** (derived) — residue block r8 with the rule's YAML; in the program: rs_section121_two_persons_section121Person1_property_ownage. 
- **cat:section_121#section121_two_persons_section121Person1_property_usage_as_principal_residence** (derived) — residue block r9 with the rule's YAML; in the program: rs_section121_two_persons_section121Person1_property_usage_as_principal_residence. 
- **cat:section_121#section121_two_persons_section121Person1_section_121_b_3_applies** (derived) — residue block r10 with the rule's YAML; in the program: rs_section121_two_persons_section121Person1_section_121_b_3_applies. 
- **cat:section_121#section121_two_persons_section121Person2_other_section_121a_sale** (derived) — residue block r11 with the rule's YAML; in the program: rs_section121_two_persons_section121Person2_other_section_121a_sale. 
- **cat:section_121#section121_two_persons_section121Person2_property_ownage** (derived) — residue block r12 with the rule's YAML; in the program: rs_section121_two_persons_section121Person2_property_ownage. 
- **cat:section_121#section121_two_persons_section121Person2_property_usage_as_principal_residence** (derived) — residue block r13 with the rule's YAML; in the program: rs_section121_two_persons_section121Person2_property_usage_as_principal_residence. 
- **cat:section_121#section121_two_persons_section121Person2_section_121_b_3_applies** (derived) — residue block r14 with the rule's YAML; in the program: rs_section121_two_persons_section121Person2_section_121_b_3_applies. 
- **cat:section_121#section121_two_persons_section121a_requirements_met** (derived) — residue block r15 with the rule's YAML; in the program: rs_section121_two_persons_section121a_requirements_met. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| Test1 | q_section121_single_person_requirements_met | pass |  |
| Test2 | q_section121_single_person_requirements_met | pass |  |
| Test3 | q_section121_single_person_requirements_met | pass |  |
| Test4 | q_section121_single_person_requirements_met | pass |  |

